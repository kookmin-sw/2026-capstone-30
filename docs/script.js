// 스크롤 시 섹션 fade-in (4단계에서 활성화)
const observer = new IntersectionObserver(
  (entries) => entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }),
  { threshold: 0.12 }
);

document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

// 네비게이션 스크롤 시 그림자 추가
window.addEventListener('scroll', () => {
  document.getElementById('navbar').style.boxShadow =
    window.scrollY > 10 ? '0 2px 16px rgba(0,0,0,0.08)' : 'none';
});
