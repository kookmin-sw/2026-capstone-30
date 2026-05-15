// 스크롤 시 fade-in
const observer = new IntersectionObserver(
  (entries) => entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }),
  { threshold: 0.1 }
);
document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

// 네비게이션 스크롤 그림자
window.addEventListener('scroll', () => {
  document.getElementById('navbar').style.boxShadow =
    window.scrollY > 10 ? '0 2px 16px rgba(0,0,0,0.08)' : 'none';
  updateActiveNav();
});

// 현재 섹션 네비 활성화
function updateActiveNav() {
  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('#navbar ul a[href^="#"]');
  let current = '';

  sections.forEach(sec => {
    if (window.scrollY >= sec.offsetTop - 80) current = sec.id;
  });

  navLinks.forEach(a => {
    a.classList.toggle('nav-active', a.getAttribute('href') === '#' + current);
  });
}

// Hero 입장 애니메이션
window.addEventListener('DOMContentLoaded', () => {
  const heroInner = document.querySelector('.hero-inner');
  const heroImages = document.querySelector('.hero-images');
  if (heroInner) {
    heroInner.style.opacity = '0';
    heroInner.style.transform = 'translateY(30px)';
    heroInner.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
    setTimeout(() => {
      heroInner.style.opacity = '1';
      heroInner.style.transform = 'translateY(0)';
    }, 100);
  }
  if (heroImages) {
    heroImages.style.opacity = '0';
    heroImages.style.transform = 'translateY(20px)';
    heroImages.style.transition = 'opacity 0.8s ease 0.3s, transform 0.8s ease 0.3s';
    setTimeout(() => {
      heroImages.style.opacity = '1';
      heroImages.style.transform = 'translateY(0)';
    }, 100);
  }
});
