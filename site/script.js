(() => {
  "use strict";

  function bindTabs(tabSelector, panelSelector) {
    const tabs = Array.from(document.querySelectorAll(tabSelector));
    const panels = Array.from(document.querySelectorAll(panelSelector));
    function select(tab, focus = false) {
      tabs.forEach((item) => {
        const active = item === tab;
        item.setAttribute("aria-selected", String(active));
        item.setAttribute("tabindex", active ? "0" : "-1");
      });
      panels.forEach((panel) => {
        panel.hidden = panel.id !== tab.getAttribute("aria-controls");
      });
      if (focus) tab.focus();
    }
    tabs.forEach((tab, index) => {
      tab.addEventListener("click", () => select(tab));
      tab.addEventListener("keydown", (event) => {
        let next = index;
        if (event.key === "ArrowRight" || event.key === "ArrowDown")
          next = (index + 1) % tabs.length;
        else if (event.key === "ArrowLeft" || event.key === "ArrowUp")
          next = (index - 1 + tabs.length) % tabs.length;
        else if (event.key === "Home") next = 0;
        else if (event.key === "End") next = tabs.length - 1;
        else return;
        event.preventDefault();
        select(tabs[next], true);
      });
    });
  }

  bindTabs(".scene-tab", ".scene-panel");
  bindTabs(".shot-tab", ".shot-panel");

  const motionButton = document.querySelector(".motion-toggle");
  const motionLabel = document.querySelector(".motion-label");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let paused = false;
  let revealObserver;

  function setMotion() {
    const stopped = paused || reducedMotion.matches;
    document.documentElement.classList.toggle("motion-paused", stopped);
    motionButton.setAttribute("aria-pressed", String(paused));
    motionButton.setAttribute(
      "aria-label",
      paused ? "开启页面动效" : "暂停页面动效",
    );
    motionLabel.textContent = paused ? "动效关" : "动效开";
    if (stopped) {
      document
        .querySelectorAll(".reveal-ready")
        .forEach((item) => item.classList.add("is-visible"));
      revealObserver?.disconnect();
    }
  }

  motionButton.addEventListener("click", () => {
    paused = !paused;
    setMotion();
  });
  reducedMotion.addEventListener("change", setMotion);
  setMotion();

  const exhibition = document.querySelector("[data-live-shot]");
  const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
  let exhibitionBounds;
  let tiltFrame = 0;
  let pointerX = 0;
  let pointerY = 0;
  function resetTilt() {
    window.cancelAnimationFrame(tiltFrame);
    tiltFrame = 0;
    exhibition.style.removeProperty("--shot-x");
    exhibition.style.removeProperty("--shot-y");
  }
  exhibition.addEventListener("pointerenter", () => {
    exhibitionBounds = exhibition.getBoundingClientRect();
  });
  exhibition.addEventListener("pointermove", (event) => {
    if (
      paused ||
      reducedMotion.matches ||
      !finePointer.matches ||
      !exhibitionBounds
    )
      return;
    pointerX =
      (event.clientX - exhibitionBounds.left) / exhibitionBounds.width - 0.5;
    pointerY =
      (event.clientY - exhibitionBounds.top) / exhibitionBounds.height - 0.5;
    if (tiltFrame) return;
    tiltFrame = window.requestAnimationFrame(() => {
      exhibition.style.setProperty(
        "--shot-x",
        `${(-pointerY * 3).toFixed(2)}deg`,
      );
      exhibition.style.setProperty(
        "--shot-y",
        `${(pointerX * 4).toFixed(2)}deg`,
      );
      tiltFrame = 0;
    });
  });
  exhibition.addEventListener("pointerleave", resetTilt);
  exhibition.addEventListener("pointercancel", resetTilt);

  if (!reducedMotion.matches && "IntersectionObserver" in window) {
    revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12 },
    );
    document
      .querySelectorAll(
        ".intro h2, .intro-bottom, .section-heading, .feature-row, .source-body, .download-title",
      )
      .forEach((item) => {
        item.classList.add("reveal-ready");
        revealObserver.observe(item);
      });
  }
})();
