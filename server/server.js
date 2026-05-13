const express = require('express');
const multer = require('multer');
const cors = require('cors');
const { config } = require('./config');
const db = require('./db');

const app = express();

// 파일 업로드 설정 
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    // 모든 이미지 형식 허용 
    if (file.mimetype.startsWith('image/') || file.mimetype === 'application/octet-stream') {
      cb(null, true);
    } else {
      cb(new Error('이미지 파일만 업로드 가능합니다.'));
    }
  },
});

// 미들웨어
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// IP 기반 레이트 리밋 (분당 30회)
const rateLimitMap = new Map();
function rateLimiter(req, res, next) {
  const ip = req.ip;
  const now = Date.now();
  const windowMs = 60 * 1000;
  const maxRequests = 30;

  if (!rateLimitMap.has(ip)) rateLimitMap.set(ip, []);
  const requests = rateLimitMap.get(ip).filter((t) => now - t < windowMs);
  requests.push(now);
  rateLimitMap.set(ip, requests);

  if (requests.length > maxRequests) {
    return res.status(429).json({ error: '요청이 너무 많습니다. 잠시 후 다시 시도하세요.' });
  }
  next();
}

// OpenRouter API 호출 
async function callOpenRouter(messages, retries = 3, maxTokens = 1024) {
  for (let attempt = 0; attempt < retries; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);

    try {
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.openrouterApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'http://localhost:3000',
          'X-Title': 'Fridge Recipe App',
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash',
          messages,
          max_tokens: maxTokens,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (response.status === 429 && attempt < retries - 1) {
        await new Promise((r) => setTimeout(r, 10000));
        continue;
      }

      return response;
    } catch (error) {
      clearTimeout(timeout);
      if (attempt === retries - 1) throw error;
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
    }
  }
}

// JSON 파싱 헬퍼
function extractJson(text) {
  const match = text.match(/\{[\s\S]*\}/);
  if (match) return JSON.parse(match[0]);
  throw new Error('JSON을 찾을 수 없습니다.');
}

const EXACT_CATEGORY = {
  '깨': '양념', '꿀': '양념', '잼': '양념', '소금': '양념', '설탕': '양념',
  '김': '해산물', '게': '해산물', '굴': '해산물',
  '무': '채소', '파': '채소', '콩': '채소',
  '김치': '채소', '배추김치': '채소', '깍두기': '채소', '총각김치': '채소',
  '단무지': '채소', '장아찌': '채소', '오이지': '채소', '나박김치': '채소', '열무김치': '채소',
  '배': '과일', '감': '과일', '귤': '과일',
};

const CATEGORY_KEYWORDS = {
  양념: ['후추', '고춧가루', '간장', '된장', '고추장', '쌈장', '참기름', '들기름', '식초', '식용유', '올리브유', '카놀라유', '미림', '맛술', '마요네즈', '케첩', '케찹', '머스타드', '굴소스', '액젓', '멸치액젓', '까나리', '다시다', '미원', '연두', '드레싱', '향신료', '계피', '바질', '오레가노', '월계수', '카레', '밀가루', '전분', '시럽', '마가린', '참깨', '들깨'],
  고기: ['소고기', '쇠고기', '돼지고기', '삼겹살', '목살', '항정살', '갈비', '등심', '안심', '닭고기', '닭가슴살', '닭다리', '닭날개', '오리고기', '양고기', '베이컨', '소시지', '핫도그', '스팸', '다짐육', '간고기', '불고기', '제육', '족발', '곱창', '대창', '막창', '치킨', '계란', '달걀', '햄'],
  채소: ['양파', '대파', '쪽파', '실파', '마늘', '생강', '당근', '감자', '고구마', '배추', '양배추', '상추', '깻잎', '시금치', '부추', '미나리', '쑥갓', '청경채', '브로콜리', '콜리플라워', '파프리카', '피망', '청양고추', '고추', '오이', '토마토', '방울토마토', '가지', '호박', '애호박', '단호박', '버섯', '표고', '느타리', '팽이', '양송이', '새송이', '콩나물', '숙주', '연근', '우엉', '도라지', '더덕', '아스파라거스', '셀러리', '비트', '래디시', '옥수수', '완두콩', '두부', '유부'],
  해산물: ['고등어', '갈치', '꽁치', '삼치', '명태', '동태', '황태', '코다리', '북어', '연어', '참치', '광어', '우럭', '도미', '조기', '굴비', '멸치', '새우', '대하', '오징어', '낙지', '주꾸미', '문어', '꼴뚜기', '조개', '바지락', '홍합', '전복', '소라', '꽃게', '대게', '랍스터', '미역', '다시마', '톳', '매생이', '파래', '명란', '알탕', '어묵', '게맛살', '맛살', '생선'],
  유제품: ['우유', '치즈', '요거트', '요구르트', '생크림', '버터', '연유', '두유', '슬라이스치즈', '체다', '모짜렐라', '모차렐라', '리코타', '크림치즈', '코티지', '플레인요거트'],
  과일: ['사과', '바나나', '딸기', '포도', '청포도', '오렌지', '레몬', '라임', '키위', '망고', '파인애플', '복숭아', '천도복숭아', '자두', '체리', '수박', '참외', '멜론', '블루베리', '라즈베리', '크랜베리', '아보카도', '단감', '홍시', '석류', '한라봉', '천혜향', '용과', '리치', '망고스틴', '두리안', '무화과', '거봉'],
};

function classifyIngredient(name) {
  if (!name) return '기타';
  const trimmed = name.trim();
  if (!trimmed) return '기타';
  if (EXACT_CATEGORY[trimmed]) return EXACT_CATEGORY[trimmed];
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (keywords.some((kw) => trimmed.includes(kw))) return category;
  }
  return '기타';
}

// 서버 상태 확인
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// 냉장고 이미지 분석
app.post('/api/analyze', rateLimiter, upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: '이미지 파일이 필요합니다.' });
  }

  const base64 = req.file.buffer.toString('base64');
  // 미지원 형식은 jpeg로 처리
  const rawMime = req.file.mimetype;
  const mimeType = rawMime.startsWith('image/') ? rawMime : 'image/jpeg';

  console.log(`[/api/analyze] 이미지 수신: ${req.file.size} bytes, ${rawMime} → ${mimeType}`);

  try {
    const response = await callOpenRouter([
      {
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: { url: `data:${mimeType};base64,${base64}` },
          },
          {
            type: 'text',
            text: '이 냉장고 사진에서 보이는 모든 식재료를 한국어로 나열해주세요. 각 재료를 쉼표로 구분하여 재료 이름만 나열해주세요. 예시: 계란, 우유, 당근, 양파',
          },
        ],
      },
    ], 3, 300);

    const data = await response.json();
    console.log(`[/api/analyze] OpenRouter 응답 status: ${response.status}`);

    if (!response.ok) {
      console.error('[/api/analyze] OpenRouter 오류:', JSON.stringify(data));
      return res.status(500).json({ error: `AI 오류: ${data.error?.message ?? response.status}` });
    }

    const text = data.choices?.[0]?.message?.content ?? '';
    console.log(`[/api/analyze] AI 응답: ${text}`);

    if (!text) {
      return res.status(500).json({ error: 'AI 응답이 비어있습니다. 다시 시도해주세요.' });
    }

    // 쉼표 구분 또는 줄바꿈 구분 모두 처리
    const raw = text.replace(/\n/g, ',');
    const ingredients = raw
      .split(',')
      .map((i) => i.trim().replace(/^[-•\d.\s]+/, '').replace(/[^\uAC00-\uD7A3a-zA-Z0-9\s]/g, '').trim())
      .filter((i) => i.length > 0 && i.length < 20);

    if (ingredients.length === 0) {
      return res.status(500).json({ error: '재료를 인식하지 못했습니다. 냉장고 내부가 잘 보이는 사진을 사용해주세요.' });
    }

    res.json({ ingredients });
  } catch (error) {
    console.error('[/api/analyze] 예외:', error.message);
    res.status(500).json({ error: `이미지 분석 실패: ${error.message}` });
  }
});

// 레시피 추천
app.post('/api/recipes', rateLimiter, async (req, res) => {
  const { ingredients, previousRecipes = [], profile = {} } = req.body;

  if (!Array.isArray(ingredients) || ingredients.length === 0) {
    return res.status(400).json({ error: '재료 목록이 필요합니다.' });
  }

  const allergiesWarning =
    profile.allergies?.length > 0
      ? `다음 알레르기 재료가 포함된 레시피는 절대 추천하지 마세요: ${profile.allergies.join(', ')}`
      : '';
  const dietaryDetailMap = {
    '채식': '고기, 해산물, 가금류가 들어간 레시피는 절대 추천하지 마세요.',
    '비건': '고기, 생선, 계란, 유제품 등 모든 동물성 식품이 들어간 레시피는 절대 추천하지 마세요.',
    '할랄': '돼지고기 및 할랄 인증이 없는 육류가 들어간 레시피는 절대 추천하지 마세요.',
  };
  const r = profile.dietaryRestriction;
  const dietaryWarning =
    r && r !== '없음' && dietaryDetailMap[r]
      ? `식이제한(${r})을 반드시 준수하세요. ${dietaryDetailMap[r]}`
      : '';
  const cuisineInfo =
    profile.preferredCuisines?.length > 0
      ? `선호 요리 종류: ${profile.preferredCuisines.join(', ')}`
      : '';
  const constraints = [allergiesWarning, dietaryWarning].filter(Boolean).join('\n');
  const prevInfo =
    previousRecipes.length > 0
      ? `\n이미 추천한 레시피(중복 제외): ${previousRecipes.join(', ')}`
      : '';

  const prompt = `당신은 전문 요리사입니다. 다음 재료로 만들 수 있는 레시피 3-5개를 추천해주세요.

사용 가능한 재료: ${ingredients.join(', ')}
${constraints ? `[필수 제한 사항 - 반드시 지켜야 합니다]\n${constraints}` : ''}
${cuisineInfo}${prevInfo}

다음 JSON 형식으로만 응답해주세요:
{
  "recipes": [
    {
      "name": "레시피 이름",
      "difficulty": "쉬움",
      "time": "20분",
      "description": "간단한 설명 (1-2문장)",
      "available": ["보유 재료1", "보유 재료2"],
      "additional": ["추가 필요 재료1"]
    }
  ]
}`;

  try {
    const response = await callOpenRouter([
      { role: 'system', content: '전문 요리사로서 JSON 형식으로만 응답합니다. 사용자의 알레르기 및 식이제한은 반드시 지켜야 하며, 위반하는 레시피는 절대 추천하지 않습니다.' },
      { role: 'user', content: prompt },
    ], 3, 1500);

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    const parsed = extractJson(text);
    res.json(parsed);
  } catch (error) {
    console.error('[/api/recipes]', error.message);
    res.status(500).json({ error: '레시피 추천에 실패했습니다.' });
  }
});

// 레시피 상세
app.post('/api/recipe-detail', rateLimiter, async (req, res) => {
  const { recipeName, ingredients = [] } = req.body;

  if (!recipeName) {
    return res.status(400).json({ error: '레시피 이름이 필요합니다.' });
  }

  const prompt = `${recipeName} 레시피의 상세한 조리 방법을 알려주세요.
${ingredients.length > 0 ? `사용 가능한 재료: ${ingredients.join(', ')}` : ''}

다음 JSON 형식으로만 응답해주세요:
{
  "name": "레시피 이름",
  "ingredients": ["재료1 (양)", "재료2 (양)"],
  "steps": ["1단계 설명", "2단계 설명", "3단계 설명"],
  "tips": "요리 팁 또는 주의사항",
  "youtubeQueries": ["검색어1", "검색어2", "검색어3"]
}

youtubeQueries는 이 레시피를 유튜브에서 검색할 때 좋은 한국어 검색어 3개입니다. 예: ["김치찌개 만들기", "김치찌개 황금레시피", "백종원 김치찌개"]`;

  try {
    const response = await callOpenRouter([
      { role: 'system', content: '전문 요리사로서 JSON 형식으로만 응답합니다.' },
      { role: 'user', content: prompt },
    ], 3, 2000);

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    const parsed = extractJson(text);

    // youtubeQueries → 인기순(조회수) 정렬 YouTube 검색 URL
    const queries = Array.isArray(parsed.youtubeQueries) ? parsed.youtubeQueries : [];
    parsed.youtubeLinks = queries.map((q) => ({
      title: q,
      url: `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}&sp=CAM%3D`,
    }));
    delete parsed.youtubeQueries;

    res.json(parsed);
  } catch (error) {
    console.error('[/api/recipe-detail]', error.message);
    res.status(500).json({ error: '레시피 상세 정보를 가져오는데 실패했습니다.' });
  }
});

// 대체 재료 추천
app.post('/api/recipes/substitute', rateLimiter, async (req, res) => {
  const { userId, missingIngredient, recipeName, recipeContext = '' } = req.body;

  if (!userId || !missingIngredient || !recipeName) {
    return res.status(400).json({ error: 'userId, missingIngredient, recipeName이 필요합니다.' });
  }

  try {
    const [rows] = await db.query('SELECT name FROM ingredients WHERE user_id = ?', [userId]);

    if (rows.length === 0) {
      return res.json({
        success: true,
        data: { original: missingIngredient, substitute: null, reason: '냉장고에 등록된 재료가 없습니다' },
      });
    }

    const [[userRow]] = await db.query(
      'SELECT diet_type FROM users WHERE user_id = ?',
      [userId]
    );
    const [allergyRows] = await db.query(
      `SELECT a.name FROM user_allergies ua
       JOIN allergies a ON ua.allergy_id = a.allergy_id WHERE ua.user_id = ?`,
      [userId]
    );

    const allergies = allergyRows.map((r) => r.name);
    const dietType = userRow?.diet_type ?? 'normal';
    const dietKr = { normal: '없음', vegetarian: '채식', vegan: '비건', halal: '할랄' }[dietType] ?? '없음';

    const allergyConstraint = allergies.length > 0
      ? `다음 알레르기 재료가 포함된 재료는 절대 추천하지 마세요: ${allergies.join(', ')}`
      : '';
    const dietConstraint = {
      vegetarian: '채식 식단입니다. 고기, 해산물, 가금류가 포함된 재료는 절대 추천하지 마세요.',
      vegan: '비건 식단입니다. 고기, 생선, 계란, 유제품 등 모든 동물성 재료는 절대 추천하지 마세요.',
      halal: '할랄 식단입니다. 돼지고기 및 할랄 인증이 없는 육류는 절대 추천하지 마세요.',
    }[dietType] ?? '';
    const constraints = [allergyConstraint, dietConstraint].filter(Boolean).join('\n');

    const ingredientsList = rows.map((r) => r.name).join(', ');
    const contextLine = recipeContext ? `- 종류: ${recipeContext}\n` : '';

    const prompt = `당신은 한식 요리 전문가입니다. 사용자의 냉장고에 있는 재료 중에서 부족한 재료를 대체할 수 있는 가장 적합한 재료 1개를 추천해주세요.

[부족한 재료]
${missingIngredient}

[레시피 정보]
- 이름: ${recipeName}
${contextLine}
[냉장고 보유 재료]
${ingredientsList}
${constraints ? `\n[필수 제한 사항 - 반드시 지켜야 합니다]\n${constraints}\n` : ''}
[중요한 원칙 - 억지로 추천하지 않기]
- 대체했을 때 요리의 정체성이 크게 훼손되거나, 맛/식감/조리 결과가 현저히 나빠진다면 추천하지 마세요.
- 핵심 재료(예: 김치찌개의 김치, 미역국의 미역)는 일반적으로 대체 불가입니다.
- 보유 재료 중 어느 것도 합리적인 대체재가 못 된다면 망설이지 말고 substitute를 null로 반환하세요.
- "없는 것보다는 낫다" 식의 억지 추천은 사용자에게 더 나쁜 경험을 줍니다.

[추천 가능 기준]
다음을 모두 만족할 때만 추천:
1. 맛/풍미 프로필이 유사하거나 호환됨
2. 식감이 비슷하거나 조리법으로 비슷하게 만들 수 있음
3. 해당 요리에서 부족 재료가 하던 역할(주재료/부재료/향신/색감 등)을 수행 가능
4. 대체 시 요리의 정체성이 유지됨

[조건]
- 반드시 위 보유 재료 목록 안에서만 추천
- 적합한 대체재가 없으면 substitute를 null로, reason에 왜 대체가 어려운지 한 문장 설명

[출력 형식 - JSON only]
적합한 경우:
{"substitute": "상추", "reason": "잎채소 특유의 아삭한 식감과 쌉싸름한 맛이 비슷해 무침류에 적합"}

적합하지 않은 경우:
{"substitute": null, "reason": "김치는 발효 풍미가 핵심이라 보유 재료로는 대체가 어렵습니다"}`;

    const response = await callOpenRouter([
      { role: 'system', content: `전문 요리사로서 JSON 형식으로만 응답합니다. 사용자의 알레르기 및 식이제한(${dietKr})은 반드시 지켜야 하며, 위반하는 재료는 절대 추천하지 않습니다.` },
      { role: 'user', content: prompt },
    ], 3, 512);

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    const parsed = extractJson(text);

    res.json({
      success: true,
      data: {
        original: missingIngredient,
        substitute: parsed.substitute ?? null,
        reason: parsed.reason ?? '',
      },
    });
  } catch (error) {
    console.error('[/api/recipes/substitute]', error.message);
    res.status(500).json({ error: '대체 재료 추천에 실패했습니다.' });
  }
});


// 아이디 중복 확인
app.get('/api/check-username/:username', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT user_id FROM users WHERE username = ?',
      [req.params.username]
    );
    res.json({ available: rows.length === 0 });
  } catch (error) {
    console.error('[/api/check-username]', error.message);
    res.status(500).json({ error: '중복 확인 실패' });
  }
});

// 회원가입
app.post('/api/register', async (req, res) => {
  const { username, password_hash, nickname } = req.body;

  if (!username || !password_hash || !nickname) {
    return res.status(400).json({ error: '아이디, 비밀번호, 닉네임이 필요합니다.' });
  }

  try {
    const [result] = await db.query(
      'INSERT INTO users (username, password_hash, nickname) VALUES (?, ?, ?)',
      [username, password_hash, nickname]
    );
    res.json({ user_id: result.insertId });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: '이미 존재하는 아이디입니다.' });
    }
    console.error('[/api/register]', error.message);
    res.status(500).json({ error: '회원가입 실패' });
  }
});

// 로그인
app.post('/api/login', async (req, res) => {
  const { username, password_hash } = req.body;

  if (!username || !password_hash) {
    return res.status(400).json({ error: '아이디와 비밀번호가 필요합니다.' });
  }

  try {
    const [rows] = await db.query(
      'SELECT user_id, username, nickname, diet_type FROM users WHERE username = ? AND password_hash = ?',
      [username, password_hash]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 틀렸습니다.' });
    }

    res.json(rows[0]);
  } catch (error) {
    console.error('[/api/login]', error.message);
    res.status(500).json({ error: '로그인 실패' });
  }
});

// 프로필 조회 (알레르기 + 선호장르 포함)
app.get('/api/users/:userId/profile', async (req, res) => {
  try {
    const userId = req.params.userId;

    const [users] = await db.query(
      'SELECT user_id, username, nickname, diet_type FROM users WHERE user_id = ?',
      [userId]
    );
    if (users.length === 0) return res.status(404).json({ error: '사용자를 찾을 수 없습니다.' });

    const [allergies] = await db.query(
      `SELECT a.allergy_id, a.name FROM user_allergies ua
       JOIN allergies a ON ua.allergy_id = a.allergy_id WHERE ua.user_id = ?`,
      [userId]
    );

    const [cuisines] = await db.query(
      `SELECT c.cuisine_id, c.name FROM user_preferred_cuisines upc
       JOIN cuisines c ON upc.cuisine_id = c.cuisine_id WHERE upc.user_id = ?`,
      [userId]
    );

    res.json({ ...users[0], allergies, preferred_cuisines: cuisines });
  } catch (error) {
    console.error('[/api/users/profile]', error.message);
    res.status(500).json({ error: '프로필 조회 실패' });
  }
});

// 프로필 수정 (식단 + 알레르기 + 선호장르)
app.put('/api/users/:userId/profile', async (req, res) => {
  const conn = await db.getConnection();
  try {
    const userId = req.params.userId;
    const { diet_type, allergy_ids, cuisine_ids } = req.body;

    await conn.beginTransaction();

    if (diet_type) {
      await conn.query('UPDATE users SET diet_type = ? WHERE user_id = ?', [diet_type, userId]);
    }

    if (Array.isArray(allergy_ids)) {
      await conn.query('DELETE FROM user_allergies WHERE user_id = ?', [userId]);
      for (const id of allergy_ids) {
        await conn.query('INSERT INTO user_allergies (user_id, allergy_id) VALUES (?, ?)', [userId, id]);
      }
    }

    if (Array.isArray(cuisine_ids)) {
      await conn.query('DELETE FROM user_preferred_cuisines WHERE user_id = ?', [userId]);
      for (const id of cuisine_ids) {
        await conn.query('INSERT INTO user_preferred_cuisines (user_id, cuisine_id) VALUES (?, ?)', [userId, id]);
      }
    }

    await conn.commit();
    res.json({ message: '프로필 수정 완료' });
  } catch (error) {
    await conn.rollback();
    console.error('[/api/users/profile PUT]', error.message);
    res.status(500).json({ error: '프로필 수정 실패' });
  } finally {
    conn.release();
  }
});

// 알레르기 목록
app.get('/api/allergies', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM allergies ORDER BY name');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: '알레르기 목록 조회 실패' });
  }
});

// 요리 장르 목록
app.get('/api/cuisines', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM cuisines ORDER BY name');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: '요리 장르 목록 조회 실패' });
  }
});

// 식재료 저장 (이름만)
app.post('/api/ingredients', async (req, res) => {
  const { user_id, ingredients } = req.body;

  if (!user_id || !Array.isArray(ingredients) || ingredients.length === 0) {
    return res.status(400).json({ error: 'user_id와 재료 목록이 필요합니다.' });
  }

  try {
    const ids = [];
    let inserted = 0;
    for (const item of ingredients) {
      const category = item.category || classifyIngredient(item.name);
      const [result] = await db.query(
        'INSERT IGNORE INTO ingredients (user_id, name, category) VALUES (?, ?, ?)',
        [user_id, item.name, category]
      );
      if (result.affectedRows > 0) {
        inserted++;
        ids.push(result.insertId);
      }
    }
    res.json({ count: inserted, ids });
  } catch (error) {
    console.error('[/api/ingredients POST]', error.message);
    res.status(500).json({ error: '식재료 저장 실패' });
  }
});

// 내 냉장고 조회
app.get('/api/ingredients/:userId', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM ingredients WHERE user_id = ? ORDER BY created_at DESC',
      [req.params.userId]
    );
    res.json(rows);
  } catch (error) {
    console.error('[/api/ingredients GET]', error.message);
    res.status(500).json({ error: '냉장고 조회 실패' });
  }
});

// 식재료 삭제
app.delete('/api/ingredients/:ingredientId', async (req, res) => {
  try {
    const [result] = await db.query(
      'DELETE FROM ingredients WHERE ingredient_id = ?',
      [req.params.ingredientId]
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: '식재료를 찾을 수 없습니다.' });
    res.json({ message: '삭제 완료' });
  } catch (error) {
    console.error('[/api/ingredients DELETE]', error.message);
    res.status(500).json({ error: '식재료 삭제 실패' });
  }
});

// FCM 토큰 저장
app.put('/api/users/:userId/fcm-token', async (req, res) => {
  try {
    await db.query('UPDATE users SET fcm_token = ? WHERE user_id = ?', [req.body.fcm_token, req.params.userId]);
    res.json({ message: 'FCM 토큰 저장 완료' });
  } catch (error) {
    console.error('[/api/users/fcm-token]', error.message);
    res.status(500).json({ error: 'FCM 토큰 저장 실패' });
  }
});

// Multer 에러 핸들러
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError || err.message.includes('허용')) {
    return res.status(400).json({ error: err.message });
  }
  console.error(err);
  res.status(500).json({ error: '서버 오류가 발생했습니다.' });
});

app.listen(config.port, '0.0.0.0', () => {
  console.log(`서버 실행 중: http://0.0.0.0:${config.port}`);
  console.log(`   Flutter 앱에서 접속 시 컴퓨터의 로컬 IP를 사용하세요.`);
});
