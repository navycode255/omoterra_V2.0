'use client';
import { useEffect } from 'react';

export function HomeMotion() {
  useEffect(() => {
    const root = document.querySelector<HTMLElement>('[data-home]');
    if (!root) return;
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const updateHeader = () => root.classList.toggle('home-scrolled', window.scrollY > 12);
    updateHeader();
    window.addEventListener('scroll', updateHeader, { passive: true });
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('home-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: .08 });
    if (!media.matches) root.querySelectorAll<HTMLElement>('[data-reveal]').forEach((element) => {
      if (element.getBoundingClientRect().top >= window.innerHeight) {
        element.classList.add('home-pending');
        observer.observe(element);
      }
    });
    return () => { observer.disconnect(); window.removeEventListener('scroll', updateHeader); };
  }, []);
  return null;
}
