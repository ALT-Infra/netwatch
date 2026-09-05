import { StrictMode, useEffect, useRef, useState, type FormEvent } from "react";
import { createRoot } from "react-dom/client";
import {
  Activity,
  ArrowRight,
  Camera as CameraIcon,
  Check,
  ChevronRight,
  CircleHelp,
  HardDrive,
  LockKeyhole,
  Monitor,
  Plus,
  Radio,
  ShieldCheck,
  Trash2,
  X,
} from "lucide-react";
import { ApiError, request, type Camera } from "./api";
import "./styles.css";

function App() {
  // Keep the access key in memory; locking or reloading clears it.
  const [token, setToken] = useState("");
  const [keyInput, setKeyInput] = useState("");
  const [cameras, setCameras] = useState<Camera[]>([]);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Camera | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const formDialog = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    if (showForm) formDialog.current?.showModal();
    else formDialog.current?.close();
  }, [showForm]);
  useEffect(() => {
    if (deleteTarget) dialog.current?.showModal();
    else dialog.current?.close();
  }, [deleteTarget]);

  function handleError(cause: unknown) {
    if (cause instanceof ApiError && cause.status === 401) {
      setToken("");
      setCameras([]);
      setShowForm(false);
      setDeleteTarget(null);
    }
    setError(
      cause instanceof Error
        ? cause.message
        : "Could not reach the edge computer.",
    );
  }

  async function unlock(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy("unlock");
    setError("");
    try {
      const key = keyInput.trim();
      await request(key, "/session");
      const items = await request<Camera[]>(key, "/cameras");
      setToken(key);
      setKeyInput("");
      setCameras(items);
    } catch (cause) {
      handleError(cause);
    } finally {
      setBusy("");
    }
  }

  async function addCamera(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy("save");
    setError("");
    setNotice("");
    const form = new FormData(event.currentTarget);
    try {
      const item = await request<Camera>(token, "/cameras", {
        method: "POST",
        body: JSON.stringify({
          name: form.get("name"),
          main_url: form.get("main_url"),
          sub_url: form.get("sub_url") || null,
          username: form.get("username") || "",
          password: form.get("password") || "",
        }),
      });
      setCameras((items) => [...items, item]);
      setShowForm(false);
      setNotice(`${item.name} saved. Check its stream to test the connection.`);
    } catch (cause) {
      handleError(cause);
    } finally {
      setBusy("");
    }
  }

  async function probe(camera: Camera) {
    setBusy(camera.id);
    setError("");
    setNotice("");
    try {
      const updated = await request<Camera>(
        token,
        `/cameras/${camera.id}/probe`,
        {
          method: "POST",
          body: JSON.stringify({ stream: "main" }),
        },
      );
      setCameras((items) =>
        items.map((item) => (item.id === updated.id ? updated : item)),
      );
      setNotice(`${camera.name}: ${updated.last_probe?.message}`);
    } catch (cause) {
      handleError(cause);
    } finally {
      setBusy("");
    }
  }

  async function removeCamera() {
    if (!deleteTarget) return;
    setBusy("delete");
    setError("");
    try {
      await request(token, `/cameras/${deleteTarget.id}`, { method: "DELETE" });
      setCameras((items) =>
        items.filter((item) => item.id !== deleteTarget.id),
      );
      setNotice(`${deleteTarget.name} removed from this workspace.`);
      setDeleteTarget(null);
    } catch (cause) {
      handleError(cause);
    } finally {
      setBusy("");
    }
  }

  const checked = cameras.filter((camera) => camera.last_probe).length;
  const reachable = cameras.filter(
    (camera) => camera.last_probe?.status === "reachable",
  ).length;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="/" aria-label="Netwatch home">
          <span className="brand-icon">
            <Radio size={23} />
          </span>
          netwatch<span className="brand-dot">.</span>
        </a>
        <div className="workspace">
          <span className="workspace-icon">
            <HardDrive size={18} />
          </span>
          <div>
            Local workspace<small>EDGE COMPUTER</small>
          </div>
          <span className="local-dot" />
        </div>
        <p className="nav-label">WORKSPACE</p>
        <nav aria-label="Workspace">
          <span className="nav-item selected" aria-current="page">
            <CameraIcon size={19} />
            Cameras<span>{cameras.length}</span>
          </span>
        </nav>
        <div className="sidebar-note">
          <ShieldCheck size={20} />
          <strong>Built to stay local</strong>
          <p>
            Camera details are stored on this computer. You control what leaves
            your site.
          </p>
        </div>
        <button className="help-button" onClick={() => setShowHelp(!showHelp)}>
          <CircleHelp size={17} />
          Connection guide
          <ChevronRight size={16} />
        </button>
        <div className="sidebar-footer">
          <span className="avatar">LW</span>
          <div>
            Local administrator<small>Camera onboarding · v0.1</small>
          </div>
        </div>
      </aside>
      <div className="main-shell">
        <header className="topbar">
          <div>
            Workspace <ChevronRight size={13} />
            <span>Cameras</span>
          </div>
          <div className="topbar-right">
            <span className="local-badge">
              <HardDrive size={13} /> Local storage
            </span>
            {token && (
              <button
                className="text-button"
                disabled={!!busy}
                onClick={() => {
                  setToken("");
                  setCameras([]);
                  setNotice("");
                  setError("");
                }}
              >
                Lock workspace
              </button>
            )}
          </div>
        </header>
        <main>
          <div className="page-heading">
            <div>
              <p className="eyebrow">YOUR SITE, CONNECTED</p>
              <h1>Camera workspace</h1>
              <p>Bring your existing cameras into one local workspace.</p>
            </div>
            {token && (
              <button
                className="primary"
                onClick={() => {
                  setError("");
                  setShowForm(true);
                }}
              >
                <Plus size={17} />
                Add camera
              </button>
            )}
          </div>
          {showHelp && (
            <section className="guide">
              <div>
                <h2>Connect an IP camera</h2>
                <p>
                  Use its RTSP stream address from the camera or NVR settings.
                  Keep the edge computer on a network that can reach it, and
                  enter the camera username and password separately.
                </p>
                <p>
                  This first version supports manual RTSP setup and an on-demand
                  video check. Live viewing, automatic discovery, and AI events
                  are upcoming milestones.
                </p>
              </div>
              <button
                className="icon-button"
                aria-label="Close guide"
                onClick={() => setShowHelp(false)}
              >
                <X size={18} />
              </button>
            </section>
          )}
          {error && !showForm && !deleteTarget && (
            <p className="error" role="alert">
              {error}
            </p>
          )}
          {notice && (
            <p className="notice" role="status">
              <Check size={16} />
              {notice}
            </p>
          )}
          {!token ? (
            <section className="unlock-panel">
              <div className="large-icon">
                <LockKeyhole size={28} />
              </div>
              <p className="eyebrow">PRIVATE BY DEFAULT</p>
              <h2>Unlock your workspace</h2>
              <p>
                Enter the access key created on your edge computer to manage its
                cameras.
              </p>
              <form onSubmit={unlock}>
                <label htmlFor="access-key">Local access key</label>
                <input
                  id="access-key"
                  type="password"
                  autoComplete="off"
                  required
                  value={keyInput}
                  onChange={(event) => setKeyInput(event.target.value)}
                  placeholder="Enter your access key"
                />
                <button className="primary" disabled={!!busy}>
                  {busy === "unlock" ? "Unlocking…" : "Unlock workspace"}
                  <ArrowRight size={17} />
                </button>
              </form>
              <small>
                Your key stays in memory until you lock or reload this page.
              </small>
            </section>
          ) : (
            <>
              <section className="stats" aria-label="Camera summary">
                <Stat
                  label="Configured cameras"
                  value={cameras.length}
                  description="Saved in this workspace"
                  icon={<CameraIcon size={19} />}
                />
                <Stat
                  label="Responded at last check"
                  value={reachable}
                  description="Manual checks · not live status"
                  icon={<Activity size={19} />}
                />
                <Stat
                  label="Awaiting first check"
                  value={cameras.length - checked}
                  description="Test the stream connection"
                  icon={<Monitor size={19} />}
                />
              </section>
              <section className="camera-section">
                <div className="section-heading">
                  <div>
                    <h2>
                      Your cameras <span>{cameras.length}</span>
                    </h2>
                    <p>Connection details and the latest stream check.</p>
                  </div>
                  <span className="subtle-label">RTSP CONNECTIONS</span>
                </div>
                {cameras.length === 0 ? (
                  <div className="empty-state">
                    <div className="camera-illustration">
                      <CameraIcon size={45} strokeWidth={1.3} />
                      <span>
                        <Plus size={12} />
                      </span>
                    </div>
                    <h3>A clearer view starts here</h3>
                    <p>
                      Add your first IP camera or NVR stream.
                      <br />
                      Your existing recording system can keep running.
                    </p>
                    <button
                      className="secondary"
                      onClick={() => {
                        setError("");
                        setShowForm(true);
                      }}
                    >
                      <Plus size={16} />
                      Add your first camera
                    </button>
                    <div className="empty-footnote">
                      <LockKeyhole size={13} />
                      Credentials are encrypted on this computer
                    </div>
                  </div>
                ) : (
                  <div className="camera-grid">
                    {cameras.map((camera) => (
                      <article className="camera-card" key={camera.id}>
                        <div className="camera-placeholder">
                          <CameraIcon size={36} strokeWidth={1.2} />
                          <span>Live preview is not connected yet</span>
                        </div>
                        <div className="card-content">
                          <div className="card-title">
                            <h3>{camera.name}</h3>
                            <button
                              className="icon-button"
                              disabled={!!busy}
                              aria-label={`Remove ${camera.name}`}
                              onClick={() => {
                                setError("");
                                setDeleteTarget(camera);
                              }}
                            >
                              <Trash2 size={15} />
                            </button>
                          </div>
                          <p className="camera-host">{camera.host}</p>
                          <div className="camera-tags">
                            <span>RTSP</span>
                            {camera.has_substream && (
                              <span>Substream saved</span>
                            )}
                            {camera.has_credentials && (
                              <LockKeyhole
                                size={12}
                                aria-label="Credentials encrypted"
                              />
                            )}
                          </div>
                          <div
                            className={`probe-state ${camera.last_probe?.status ?? "unchecked"}`}
                          >
                            <span className="status-dot" />
                            {camera.last_probe
                              ? camera.last_probe.status === "reachable"
                                ? "Responded at last check"
                                : "Last check failed"
                              : "Not checked yet"}
                          </div>
                          {camera.last_probe?.width && (
                            <p className="stream-detail">
                              {camera.last_probe.width} ×{" "}
                              {camera.last_probe.height} ·{" "}
                              {camera.last_probe.codec}
                            </p>
                          )}
                          {camera.checked_at && (
                            <p className="stream-detail">
                              {camera.last_probe?.stream === "sub"
                                ? "Substream"
                                : "Main stream"}{" "}
                              checked{" "}
                              {new Date(camera.checked_at).toLocaleString()}
                            </p>
                          )}
                          <button
                            className="check-button"
                            disabled={!!busy}
                            onClick={() => probe(camera)}
                          >
                            <Activity size={15} />
                            {busy === camera.id
                              ? "Checking stream…"
                              : "Check main stream"}
                            <ArrowRight size={14} />
                          </button>
                        </div>
                      </article>
                    ))}
                  </div>
                )}
              </section>
              <div className="bottom-note">
                <ShieldCheck size={18} />
                <p>
                  <strong>Your cameras. Your network.</strong> Video processing
                  will run at your site. This workspace currently manages camera
                  connections.
                </p>
              </div>
            </>
          )}
        </main>
        <footer className="page-footer">
          <span>NETWATCH / EDGE WORKSPACE</span>
          <span>Local first. Human reviewed.</span>
        </footer>
      </div>
      <dialog
        ref={formDialog}
        aria-labelledby="add-camera-title"
        onCancel={(event) => {
          if (busy) event.preventDefault();
          else setShowForm(false);
        }}
        onClose={() => setShowForm(false)}
      >
        <form onSubmit={addCamera} key={String(showForm)}>
          <div className="dialog-heading">
            <div>
              <p className="eyebrow">CAMERA CONNECTION</p>
              <h2 id="add-camera-title">Add a camera</h2>
            </div>
            <button
              type="button"
              className="icon-button"
              aria-label="Close add camera"
              disabled={!!busy}
              onClick={() => setShowForm(false)}
            >
              <X size={20} />
            </button>
          </div>
          <p className="dialog-intro">
            Use an RTSP address from your IP camera or NVR.
          </p>
          {error && (
            <p className="error" role="alert">
              {error}
            </p>
          )}
          <label htmlFor="camera-name">Camera name</label>
          <input
            id="camera-name"
            name="name"
            required
            maxLength={80}
            placeholder="e.g. Warehouse entrance"
          />
          <label htmlFor="main-url">Main stream URL</label>
          <input
            id="main-url"
            name="main_url"
            required
            maxLength={2048}
            placeholder="rtsp://192.168.1.20:554/stream1"
            autoComplete="off"
          />
          <label htmlFor="sub-url">
            Substream URL <span>optional</span>
          </label>
          <input
            id="sub-url"
            name="sub_url"
            maxLength={2048}
            placeholder="rtsp://192.168.1.20:554/stream2"
            autoComplete="off"
          />
          <div className="form-row">
            <div>
              <label htmlFor="username">Camera username</label>
              <input
                id="username"
                name="username"
                maxLength={512}
                autoComplete="off"
              />
            </div>
            <div>
              <label htmlFor="password">Camera password</label>
              <input
                id="password"
                name="password"
                type="password"
                maxLength={512}
                autoComplete="new-password"
              />
            </div>
          </div>
          <p className="form-note">
            <LockKeyhole size={14} />
            Credentials are encrypted and never returned by the API.
          </p>
          <div className="dialog-actions">
            <button
              type="button"
              className="secondary"
              disabled={!!busy}
              onClick={() => setShowForm(false)}
            >
              Cancel
            </button>
            <button className="primary" disabled={!!busy}>
              {busy === "save" ? "Saving…" : "Save camera"}
              <ArrowRight size={16} />
            </button>
          </div>
        </form>
      </dialog>
      <dialog
        ref={dialog}
        aria-labelledby="remove-camera-title"
        onCancel={(event) => {
          if (busy) event.preventDefault();
          else setDeleteTarget(null);
        }}
      >
        <h2 id="remove-camera-title">Remove {deleteTarget?.name}?</h2>
        <p>
          This removes its saved connection from this workspace. It does not
          change the camera or NVR.
        </p>
        {error && (
          <p className="error" role="alert">
            {error}
          </p>
        )}
        <div className="dialog-actions">
          <button
            className="secondary"
            disabled={!!busy}
            onClick={() => setDeleteTarget(null)}
          >
            Keep camera
          </button>
          <button className="danger" disabled={!!busy} onClick={removeCamera}>
            {busy === "delete" ? "Removing…" : "Remove camera"}
          </button>
        </div>
      </dialog>
    </div>
  );
}

function Stat({
  label,
  value,
  description,
  icon,
}: {
  label: string;
  value: number;
  description: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="stat">
      <div className="stat-heading">
        {label}
        {icon}
      </div>
      <strong>{value.toString().padStart(2, "0")}</strong>
      <small>{description}</small>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
