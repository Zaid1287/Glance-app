// Progressive enhancement. Hero + mock animate via CSS on load (robust, no
// scroll gating). JS handles: below-the-fold reveals, the mock's finish/replay,
// and copy buttons. No-JS shows everything; reduced-motion shows finished states.
(() => {
  document.documentElement.classList.add("js");

  // Below-the-fold staggered reveal
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        if (e.target.dataset.i) e.target.style.transitionDelay = parseInt(e.target.dataset.i, 10) * 70 + "ms";
        e.target.classList.add("in");
        io.unobserve(e.target);
      }
    },
    { threshold: 0.16, rootMargin: "0px 0px -8% 0px" }
  );
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  // Live-Activity mock: CSS fills the bar; mark .done when it finishes; replay on click
  const mock = document.getElementById("mock");
  if (mock) {
    const fill = mock.querySelector(".la-fill");
    fill.addEventListener("animationend", () => mock.classList.add("done"));
    mock.addEventListener("click", () => {
      mock.classList.remove("done");
      mock.querySelectorAll(".la-fill, .la-status .pct").forEach((n) => {
        n.style.animation = "none";
        void n.offsetWidth; // reflow to restart
        n.style.animation = "";
      });
    });
  }

  // Copy-to-clipboard (icon swaps to a check)
  function wireCopy(btnId, codeId) {
    const btn = document.getElementById(btnId);
    const code = document.getElementById(codeId);
    if (!btn || !code) return;
    btn.addEventListener("click", () => {
      navigator.clipboard.writeText(code.textContent.trim()).then(() => {
        btn.classList.add("copied");
        setTimeout(() => btn.classList.remove("copied"), 1600);
      });
    });
  }
  wireCopy("copy", "cmd");
  wireCopy("copy2", "cmd2");
})();
