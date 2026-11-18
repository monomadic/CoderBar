import download from "./download.json";

const repo = "https://github.com/monomadic/CoderBar";
const timings = [["Hover delay", "20"], ["Expand", "100"], ["Collapse", "100"], ["Mouse-leave delay", "20"]];

function Brand({ large = false }: { large?: boolean }) {
  return <img className={large ? "hero-brand" : "brand-icon"} src="/product/coderbar-brand.png" alt={large ? "CoderBar chocolate bar in blue and pink foil" : ""} width={large ? 240 : 40} height={large ? 240 : 40} />;
}

export default function Home() {
  return <main id="top">
    <nav className="nav shell" aria-label="Main navigation">
      <a className="brand" href="#top"><Brand /><span>CoderBar</span></a>
      <div className="nav-links"><a href="#app">The app</a><a href="#details">What’s new</a><a href="#install">Install</a></div>
      <a className="source-link" href={repo}>GitHub ↗</a>
    </nav>

    <section className="hero shell">
      <Brand large />
      <p className="eyebrow">A little bar. A lot going on.</p>
      <h1>CoderBar<span>Your agents, a glance away.</span></h1>
      <p className="lede">Codex and Claude, right beside your Mac’s notch. See what’s working, what’s waiting, and what’s done. Then jump straight back in.</p>
      <div className="actions"><a className="button primary" href="/downloads/CoderBar-macos.zip" download>Download <span>↓</span></a><a className="button secondary" href="#app">Take a look <span>↓</span></a></div>
      <p className="download-size">{download.label} · ZIP download</p>
      <p className="requirements">macOS 14+ <span>·</span> Apple silicon <span>·</span> Native SwiftUI + AppKit</p>
    </section>

    <section className="showcase shell" id="app" aria-labelledby="showcase-title">
      <div className="section-label">SMALL WHEN QUIET</div>
      <h2 id="showcase-title">Just enough to keep you in the loop.</h2>
      <div className="compact" aria-label="Illustration of minimized CoderBar with five sessions">
        <div className="wing"><img src="/product/chatgpt.png" width="15" height="15" alt="ChatGPT" /><span className="bars"><i /><i /><i /></span></div><div className="notch" /><div className="count-wing"><span>5</span></div>
      </div>
      <p className="compact-caption">An icon, a little activity, and your session count.<br />Sized around your display’s notch.</p>
      <figure className="app-figure">
        <div className="shot-heading"><span><i /> THE CURRENT APP</span><span>Expanded · content-hugging height</span></div>
        <img src="/product/coderbar-current-expanded.png" alt="Current CoderBar app showing four Claude sessions, colored project pills, model badges, elapsed time, and Done status" width="1056" height="488" />
        <figcaption>Captured from the installed app. Shown with Claude sessions; Codex lives here too. Usage appears when available.</figcaption>
      </figure>
      <div className="supported"><span>At home with</span><strong>Codex</strong><strong>Claude Code</strong><strong>Claude Desktop</strong></div>
    </section>

    <section className="details shell" id="details">
      <div className="section-label">A CLEARER VIEW OF THE WORK</div><h2>Less chrome.<br />More context.</h2>
      <div className="feature-grid">
        <article><span className="feature-number">01 / SEE</span><h3>Every session has its place.</h3><p>Regular system text, time beside the title, and a project pill that keeps its color across sessions and restarts. Models stay visible without competing for attention.</p><div className="sample"><span className="project-pill">CoderBar</span><span className="done">Done</span></div></article>
        <article><span className="feature-number">02 / RETURN</span><h3>One click back to work.</h3><p>Select a session to return to its agent app, terminal, or tmux pane, depending on the integration. A completed task simply says “Done.”</p><a className="text-link" href={`${repo}#how-you-use-it`}>Explore the integrations ↗</a></article>
        <article><span className="feature-number">03 / RESPOND</span><h3>Keep things moving.</h3><p>Supported hook integrations bring approval requests, plan reviews, questions, task plans, and sub-agents into the panel. Available controls depend on the agent and event source.</p></article>
      </div>
    </section>

    <section className="motion shell">
      <div><div className="section-label">FEELS LIKE YOUR MAC</div><h2>Quick to open.<br />Yours to fine-tune.</h2><p>The panel stays anchored to the notch as it expands. Its opaque near-black dashboard grows with the session list. The minimized view keeps a subtle translucent finish.</p><p>Adjust all four timings in Settings → General. Each accepts 0–1,000 ms, saves automatically, and can be reset to the defaults.</p></div>
      <div className="timing-panel"><div className="timing-heading">Your pace.<span>Default timings</span></div>{timings.map(([label, value]) => <div className="timing-row" key={label}><span>{label}</span><strong>{value}<small>ms</small></strong></div>)}<div className="timing-foot">No waiting around required.</div></div>
    </section>

    <section className="local shell" id="privacy"><div className="section-label">LOCAL BY DESIGN</div><h2>Close to your work.<br />Light on repeat work.</h2><div className="local-columns"><p>CoderBar reads local session indexes and transcripts, with local hooks for timely events. No CoderBar account or hosted transcript service. Preferences and event history stay on your Mac.</p><p>Discovery polls every 1.5 seconds. Bounded caches reuse parsed files until they change, avoiding repeated reads and parsing while keeping the same polling interval.</p></div></section>

    <section className="install shell" id="install"><Brand /><div className="section-label">UNWRAP YOUR NEXT WORKFLOW</div><h2>Keep your agents nearby.</h2><p>Download the current packaged app, or build from source.</p><div className="actions"><a className="button primary" href="/downloads/CoderBar-macos.zip" download>Download <span>{download.label} ↓</span></a><a className="button secondary" href={`${repo}#build-and-install`}>Build from source ↗</a></div><pre aria-label="Build from source commands"><code>git clone https://github.com/monomadic/CoderBar.git{"\n"}cd CoderBar{"\n"}zsh Scripts/build.sh{"\n"}open dist/CoderBar.app</code></pre><p className="install-note">A compatible Swift toolchain is required for source builds. The README covers installation, hooks, local data, and the pinned vendored build.</p></section>

    <footer className="footer shell"><a className="brand" href="#top"><Brand /><span>CoderBar</span></a><p>monomadic’s fork of <a href="https://github.com/helloyulife/CoderBar">helloyulife/CoderBar</a>.</p><div><a href={`${repo}#readme`}>README ↗</a><a href={repo}>Source ↗</a></div></footer>
  </main>;
}
