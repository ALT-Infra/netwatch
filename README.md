# netwatch

Technical research brief and source map for a graduation project that can grow into a brownfield CCTV-analytics product.

**Evidence cutoff:** 5 September 2026; independently reviewed<br>
**Status:** implementation started — local camera onboarding foundation; no production deployment yet

## Implementation

The onboarding foundation includes a Python/FastAPI API, React/TypeScript camera workspace, SQLite with
encrypted camera connections, manual RTSP checks, Docker Compose, and a private Frigate config
handoff. The pinned Frigate development patch series starts the upstream credential hardening.
Live video, ONVIF discovery, AI detection and event rules are not implemented yet.

See [development and startup instructions](docs/development.md) and the
[Frigate integration status](integrations/frigate/README.md).

## Repository contents

- [`edge/`](./edge/) — authenticated camera API, encrypted storage, stream checks and config export.
- [`web/`](./web/) — React/TypeScript local camera workspace.
- [`integrations/frigate/`](./integrations/frigate/) — pinned upstream and development patch series.
- [`docs/development.md`](./docs/development.md) — startup, verification and current limitations.
- [`report.typ`](./report.typ) — the complete, editable research brief.
- [`architecture.html`](./architecture/architecture.html) — interactive, offline system map; open directly in a desktop browser.
- `README.md` — conclusions, deployment model, and the curated evidence map below.

The research sources below remain the architecture baseline. Full papers, upstream checkouts,
model checkpoints, secrets and rendered artifacts are not committed. Every catalog entry points
directly to its authoritative upstream URL and records why it mattered.

## Conclusion

> Build a **brownfield, edge-first video-event engine**, not a universal cloud “threat AI.”

The edge initiates ONVIF discovery/configuration and RTSP pulls from reachable cameras or NVR channels. Compressed video branches to a local evidence buffer **before** the separate decode → detect → track → rule path. Incidents link metadata to clips and operator decisions. The existing NVR keeps its own archive. A desktop browser connects to the edge's authenticated local UI; an optional hosted service receives only explicitly enabled exports. Explore the protocols, storage and ownership in the [interactive system map](./architecture/architecture.html).

The **edge node** is an ordinary computer at the customer’s premises. For the thesis it can be an existing Ubuntu PC or mini-PC. Commercially, the same software can be offered as either:

1. A supported installer for compatible customer hardware.
2. A preconfigured box supplied by us—the easier default to benchmark and support.

Primary inference runs locally. A future hosted service can handle fleet management, health, remote delivery and signed updates. Local login and rules remain independent of it. With WAN disconnected, LAN viewing, recording, inference and local incident updates survive while the edge and LAN have power. Browser-provider WebPush and remote delivery do not. The edge stores a bounded second copy for evidence because arbitrary NVR playback/export cannot be assumed.

## Foundation and reuse decision

**Start with a controlled Frigate fork. Preserve its media, recording, tracking, review and UI internals; own distinct incident/policy modules inside that foundation.** Missing plug compatibility is expected adaptation work, not a reason to reject useful code. Our recommendation is about work saved, not combining projects for its own sake.

An external service beside stock Frigate suits existing installations, but leaves internal security changes and detailed track access unresolved. A first-party core around MediaMTX/FFmpeg is credible, yet we would have to build supervision, clocks, retention, review, authorization and upgrades ourselves. DL Streamer supplies Intel pipeline/analytics elements, not that entire application. Viseron is another real permissive foundation; the review found no demonstrated advantage for this scope. See the [comparison and switch criteria](./audit.md#foundation-decision-preserve-a-useful-whole-own-the-product-seams).

There is **no mandatory commercial rewrite**. Replace individual boundaries only when target measurements or fork maintenance justify it. Keep upstream history, patch attribution and one restream owner. The selected deployment does not include MediaMTX or DL Streamer alongside the Frigate pipeline.

| Layer | First capability | Later, only when justified |
|---|---|---|
| Local application | Controlled Frigate fork + our incident/verdict module | Same foundation; optional fleet/event adapters |
| Camera/media | Embedded go2rtc + Frigate/FFmpeg recording | MediaMTX can replace the media boundary |
| Intel video pipeline | Supported Linux box, measured decode and OpenVINO | DL Streamer/GStreamer can replace a CV worker |
| Perception | Supported OpenVINO SSD baseline + inherited Norfair | Compare RTMDet export/adapter and ByteTrack on target data |
| Decisions | One person-in-zone incident + decoded-frame health | Explicit line, direction, schedule and dwell semantics |
| Specialist AI | None | Separately validated, advisory/shadow experiments |
| Cloud | Not required | Optional control plane; OVMS **or** Triton only when scale warrants it |

The smallest complete capability is below. Frozen/covered/blurred detection is not equivalent to decoded-frame liveness; a static night scene can defeat simple image hashes/statistics. Other rule types need calibration and explicit time/gap behavior. Falls, smoke/fire, fights, weapons and generic anomaly detection remain separately validated research or advisory modules. Exclude face identification, emotion inference, cross-camera identity tracking and audio by default.

**Release constraint:** this is not permission to ship stock Frigate 0.17.2. The [source audit](./audit.md#hardening-changes-that-affect-the-choice) adds media-access and regex issues to the original credential/log finding, and corrects the bundled go2rtc/FFmpeg versions. A reviewed patch set, actual binary/license inventory and security regression checks precede a pilot. No CCTV code or new dependencies were installed in this review.

## First implementation proposal

**One camera → one locally reviewable person-in-zone incident.**

- **Input:** authorized H.264 RTSP video, camera credentials, one polygon and a supported Intel Linux PC. Start with one operator and one person rule; ONVIF helps resolve stream URLs when available, with manual RTSP fallback.
- **Process:** reuse Frigate's supported OpenVINO SSDLite MobileNet v2 detector, Norfair, bottom-center zone evaluation, recording/index and local web UI. Require two seconds of presence with a declared short-gap grace. Add our incident ID/camera epoch, policy version, open/closed/evidence state, deduplication and persistent operator verdict. RTMDet is a later measured challenger, not an initial integration prerequisite.
- **Output:** an immediate local incident card and notification in the open UI; a playable clip with five seconds before and ten seconds after qualification when available; camera health; acknowledgement plus true/false/uncertain verdict. Evidence remains pending until ready and explicitly missing if the source/storage failed. Reconnect must reset trajectories without silently losing the incident history.
- **Proof:** timestamped replay plus live-camera checks; at least 20 declared positive traversals and short/boundary/occlusion negatives; 72 valid negative camera-hours with frozen settings. Target ≥90% staged recall and p95 local UI delivery ≤3 seconds after qualification, reporting counts, intervals and evidence-ready latency separately. Check duplicate suppression, clip alignment, verdict persistence, authenticated media access and secret redaction. Inject stream/decode loss, restart, full evidence quota and WAN outage; report blind time, never count it as correctly monitored footage.

Zero false incidents over 72 negative camera-hours only bounds the stationary Poisson rate at approximately one/day with one-sided 95% confidence. It is not proof across sites. Measure delivered nuisance notifications and false incidents separately, and agree a **site-wide** interruption budget before scaling; one/day/rule can multiply into dozens of alerts.

Implementation has started with the camera-onboarding foundation described above. The complete
person-in-zone capability remains proposed work until Frigate runtime integration is validated.

## Deployment contract

- **Onboarding:** WS-Discovery UDP 3702 is usually limited to the local segment; ONVIF SOAP over HTTP(S) resolves profiles/URIs. NVR PoE networks may need an authorized channel export or routing. Credentials, vendor support, stream limits and camera access still require installer work. The edge initiates RTSP; compressed RTP video returns over TCP interleaving initially. Main/substreams and the NVR can consume separate sessions.
- **Media and time:** keep compressed evidence recording separate from decoded CV frames. Sampling at 5 FPS does not guarantee 5 FPS decode cost. Record source PTS, local monotonic arrival/qualification times and camera epochs; test main/substream offsets and reconnect. Start browser playback with H.264; H.265 may require tested platform support or explicit transcoding.
- **Storage:** NVR owns its archive; edge owns incident metadata and bounded evidence. At 4 Mbit/s, one hour is roughly 1.8 GB/camera before overhead. Set retention/quota before use, preserve the configured pre/post-roll window and visibly report expired/missing clips. Frigate emergency cleanup can remove old recordings regardless of retention; evidence references must tolerate it. [Recording behavior](https://github.com/blakeblackshear/frigate/blob/v0.17.2/docs/docs/configuration/record.md).
- **Local trust:** camera VLAN and edge internal media ports are restricted. Desktop UI uses authenticated HTTPS/WSS, with per-camera authorization on all evidence paths. Credentials live in a protected local store with an explicit host-root/unattended-restart boundary. A motion mask only changes inference; it does **not** redact stored or exported video. Privacy redaction requires a separate tested media transformation, often re-encoding.
- **Optional egress:** disabled by default. Allowlisted event metadata/health are separate from opt-in thumbnails/clips, which can contain personal data. An edge-initiated TLS connection can receive locally validated configuration/signed updates; no arbitrary camera URLs or shell instructions. Outbox IDs/retries, expiry and storage limits are later work. Apply retention/deletion/access policy to hosted copies and backups as well as local evidence; pseudonymous track IDs do not make footage anonymous.
- **Outages:** local credentials, cached models/rules, incident database and LAN UI keep working without internet. Remote WebPush/email and hosted access wait/fail visibly; they are not the offline alarm path. Remote clip viewing requires an authorized media connection or selected upload. The NVR continues independently only while its own power/network/storage work. [Frigate notifications](https://github.com/blakeblackshear/frigate/blob/v0.17.2/docs/docs/configuration/notifications.md).

## Evidence map

Labels: **Use** = recommended component; **Integrate** = support when customers already run it; **Reference** = useful design or experiment, not a production dependency; **Reject** = inspected but unsuitable as the foundation.

<details>
<summary><strong>Software and source inspections</strong></summary>

### Media, NVR, and edge infrastructure

| Source | Decision | Why it mattered |
|---|---|---|
| [Frigate](https://github.com/blakeblackshear/frigate) | **Controlled foundation** | Retain integrated media/review/UI; own incident/policy modules. Stable 0.17.2 requires the broader [source-backed hardening](./audit.md#hardening-changes-that-affect-the-choice); 0.18 is prerelease. |
| [go2rtc](https://github.com/AlexxIT/go2rtc) | **Use inside Frigate** | Low-latency ingest/restream and browser delivery; insecure LAN defaults require an authenticated boundary. |
| [MediaMTX](https://github.com/bluenviron/mediamtx) | **Alternative** | Routing, recording/playback, hooks and metrics. Replace a media boundary if justified; not part of the selected deployment. Harden anonymous defaults. |
| [FFmpeg](https://ffmpeg.org/) | **Use** | Compatibility floor for decode, probe, remux, and clips. Redistribution depends on actual build flags/codecs. |
| [DL Streamer](https://github.com/open-edge-platform/dlstreamer) | **Alternative CV worker** | Intel GStreamer/OpenVINO and analytics primitives, not the operator product. Check version-specific discovery/rules, hardware matrix and event adapter. |
| [OpenVINO Model Server](https://github.com/openvinotoolkit/model_server) | **Later / optional** | KServe inference on Intel; no native authentication or transport encryption. |
| [NVIDIA Triton](https://github.com/triton-inference-server/server) | **Later / optional** | Broad backends, scheduling, and telemetry; assumes a trusted network and is excessive for one box. |
| [ONVIF specifications](https://github.com/onvif/specs) | **Normative reference** | Discovery, streams, events, metadata, and 2026 protocol additions. Specification terms differ from software licenses. |
| [ONVIF Media Signing Framework](https://github.com/onvif/media-signing-framework) | **Future reference** | Evidentiary integrity for exported video; premature for the thesis. |

### Existing VMS and alternative implementations

| Source | Decision | Why it mattered |
|---|---|---|
| [ZoneMinder](https://github.com/ZoneMinder/zoneminder) | **Integrate, not core** | Mature GPL-2.0 Linux NVR/events/API. Stable ONVIF is marked experimental; AI is external. |
| [zmeventnotificationNg](https://github.com/ZoneMinder/zmeventnotificationNg) | **Reference for adapter** | Current event/rules/WebSocket/MQTT companion; version 7.0 calls itself development software. |
| [pyzmNg](https://github.com/ZoneMinder/pyzmNg) | **Reference** | ZoneMinder API plus local/remote YOLO ONNX, face, and ALPR pipelines; GPL and optional Ultralytics dependency complicate reuse. |
| [Viseron](https://github.com/roflcoopter/viseron) | **Reference** | Active local NVR/CV comparison, but overlaps Frigate’s responsibilities. |
| [Norfair](https://github.com/tryolabs/norfair) | **Reference / inherited** | Frigate’s customizable tracker path; no reason to make it a separate service. |
| [Supervision](https://github.com/roboflow/supervision) | **Experiment** | Convenient annotation, zones, and tracking utilities; rapidly changing API. |
| [use-go/onvif](https://github.com/use-go/onvif) | **Reject as foundation** | Permissive but inactive and rougher than the inspected current integration paths. |
| [ZoneMinder legacy event server](https://github.com/pliablepixels/zmeventserver) | **Reject** | Repository directs new users to zmeventnotificationNg. |

### Models and training ecosystems

| Source | Decision | Why it mattered |
|---|---|---|
| [MMDetection](https://github.com/open-mmlab/mmdetection) | **Training/export candidate** | RTMDet is worth measuring; Apache-2.0 code. Head remains February 2024 with old version bounds. Export still needs a Frigate model adapter and separate weight/data rights. |
| [ByteTrack](https://github.com/FoundationVision/ByteTrack) | **Borrow/benchmark later** | MIT association algorithm; head remains December 2022 and environment pins are old. Retain Norfair until target track/rule outcomes favor replacement. |
| [MMPose](https://github.com/open-mmlab/mmpose) | **Specialist reference** | RTMPose foundation for a fall/person-down experiment. |
| [MMAction2](https://github.com/open-mmlab/mmaction2) | **Specialist reference** | Temporal/action training toolkit. |
| [PyTorchVideo](https://github.com/facebookresearch/pytorchvideo) | **Specialist reference** | X3D-XS backbone seed; its Kinetics checkpoint is not a threat model. |
| [GroundingDINO](https://github.com/IDEA-Research/GroundingDINO) | **Offline/second stage** | Open-vocabulary labeling or crop verification; checkpoint rights and CCTV small-object behavior need audit. |
| [VadCLIP](https://github.com/nwpu-zxr/VadCLIP) | **Research only** | Reproducible VAD baseline; benchmark-specific features and upstream rights prevent a production assumption. |
| [LAVIDA](https://github.com/VitaminCreed/LAVIDA) | **Watch** | 2026 MIT source, but no trained LAVIDA checkpoint and incomplete usage/data instructions at cutoff. |
| [AnyAnomaly](https://github.com/SkiddieAhn/Paper-AnyAnomaly) | **Research only** | Prompt/pipeline wrapper around upstream LVLMs; no original trained checkpoint. |
| [CCTV-Gun](https://github.com/srikarym/CCTV-Gun) | **Failure-analysis reference** | Direct evidence of severe cross-dataset and tiny-object handgun limits. |
| [D-Fire](https://github.com/gaia-solutions-on-demand/DFireDataset) | **Dataset seed** | CC0 fire/smoke image collection; does not estimate live camera-hour false alarms. |
| [Fire-Detection](https://github.com/pedbrgs/Fire-Detection) | **Reject as dependency** | Root MIT declaration conflicts with vendored GPL-3.0 YOLOv5 files; checkpoint terms are unclear. |

</details>

<details>
<summary><strong>Core computer-vision research</strong></summary>

| Work | Status | Why it mattered |
|---|---|---|
| [Real-world Anomaly Detection in Surveillance Videos](https://openaccess.thecvf.com/content_cvpr_2018/html/Sultani_Real-World_Anomaly_Detection_CVPR_2018_paper.html) | CVPR 2018 | UCF-Crime and weakly supervised VAD; influential, not deployment evidence. |
| [Street Scene](https://openaccess.thecvf.com/content_WACV_2020/html/Ramachandra_Street_Scene_A_new_dataset_and_evaluation_protocol_for_video_WACV_2020_paper.html) | WACV 2020 | Exposed weaknesses in frame/pixel metrics and older small/staged datasets. |
| [Generalizable Pedestrian Detection](https://openaccess.thecvf.com/content/CVPR2021/html/Hasan_Generalizable_Pedestrian_Detection_The_Elephant_in_the_Room_CVPR_2021_paper.html) | CVPR 2021 | Demonstrated cross-dataset degradation even for ordinary pedestrian detection. |
| [RTFM](https://openaccess.thecvf.com/content/ICCV2021/html/Tian_Weakly-Supervised_Video_Anomaly_Detection_With_Robust_Temporal_Feature_Magnitude_Learning_ICCV_2021_paper.html) | ICCV 2021 | Major weakly supervised VAD baseline. |
| [Rethinking VAD as Continual Learning](https://openaccess.thecvf.com/content/WACV2022/html/Doshi_Rethinking_Video_Anomaly_Detection_-_A_Continual_Learning_Approach_WACV_2022_paper.html) | WACV 2022 | Challenged the assumption that training contains every normal behavior. |
| [ByteTrack](https://arxiv.org/abs/2110.06864) | ECCV 2022 | Practical low-score association strategy for multi-object tracking. |
| [RTMDet](https://arxiv.org/abs/2212.07784) | Technical report | Efficient detector family; quoted model latency excludes the live-video pipeline. |
| [NWPU Campus benchmark](https://openaccess.thecvf.com/content/CVPR2023/html/Cao_A_New_Comprehensive_Benchmark_for_Semi-Supervised_Video_Anomaly_Detection_and_CVPR_2023_paper.html) | CVPR 2023 | More scenes and anomaly types; still substantially enacted and benchmark-centric. |
| [Cross-Domain VAD](https://openaccess.thecvf.com/content/WACV2023/html/Aich_Cross-Domain_Video_Anomaly_Detection_Without_Target_Domain_Adaptation_WACV_2023_paper.html) | WACV 2023 | Direct domain-shift research. |
| [Real-Time Weakly Supervised VAD](https://openaccess.thecvf.com/content/WACV2024/html/Karim_Real-Time_Weakly_Supervised_Video_Anomaly_Detection_WACV_2024_paper.html) | WACV 2024 | Online-window degradation, multi-second evidence delay, and benchmark-confound warning. |
| [VadCLIP](https://ojs.aaai.org/index.php/AAAI/article/view/28518) | AAAI 2024 | Strong language-guided VAD baseline whose false-alarm behavior needs operating-point analysis. |
| [Evaluating VAD in the Wild](https://openaccess.thecvf.com/content/CVPR2024W/ABAW/html/Yao_Evaluating_the_Effectiveness_of_Video_Anomaly_Detection_in_the_Wild_CVPRW_2024_paper.html) | CVPRW 2024 | ShanghaiTech-trained methods fell near chance on unseen CHAD cameras. |
| [Grounding DINO](https://www.ecva.net/papers/eccv_2024/papers_ECCV/html/694_ECCV_2024_paper.php) | ECCV 2024 | Open-vocabulary detection for labeling and second-stage experiments. |
| [Florence-2](https://openaccess.thecvf.com/content/CVPR2024/html/Xiao_Florence-2_Advancing_a_Unified_Representation_for_a_Variety_of_Vision_CVPR_2024_paper.html) | CVPR 2024 | Compact general vision model; image-centric rather than temporal threat recognition. |
| [MHBench](https://doi.org/10.1609/aaai.v39i4.32463) | AAAI 2025 | Direct evidence of motion hallucination in VideoLLMs. |
| [CCTV-Gun](https://arxiv.org/abs/2303.10703) | Unreviewed manuscript | Handguns averaged only 16 pixels in one target dataset; key cross-dataset AP50 results were 3.7–7.7. |
| [RWF-2000](https://arxiv.org/abs/1911.05913) | ICPR 2020 / author manuscript | Fight-data seed; balanced trimmed web clips do not estimate live false alerts. |
| [Abandoned-object survey](https://www.mdpi.com/1424-8220/18/12/4290) | Sensors 2018 | The task is tracking, persistence, and ownership reasoning—not one class label. |

</details>

<details>
<summary><strong>Dedicated 2026 research pass</strong></summary>

| Work | Status | Product reading |
|---|---|---|
| [The Road Less Seen](https://openaccess.thecvf.com/content/CVPR2026/html/Acharya_The_Road_Less_Seen_Segment_Exploration_for_Weakly_Supervised_Video_CVPR_2026_paper.html) | CVPR 2026 | Strong AUROC can coexist with low recall at tolerable FPR and huge false-alert counts. |
| [LAVIDA](https://openaccess.thecvf.com/content/CVPR2026/html/Dai_No_Need_For_Real_Anomaly_MLLM_Empowered_Zero-Shot_Video_Anomaly_CVPR_2026_paper.html) | CVPR 2026 | Promising zero-shot benchmark/localization work; no camera-day operating point or released trained checkpoint found. |
| [ACCIDENT](https://openaccess.thecvf.com/content/CVPR2026W/AUTOPILOT/html/Picek_ACCIDENT_A_Benchmark_Dataset_for_Vehicle_Accident_Detection_from_Traffic_CVPRW_2026_paper.html) | CVPRW 2026 | Quoted weak scores are five-way collision-type classification in accident clips, not accident/no-accident detection. VLM spatial localization beats simple priors; no normal-stream false-alert rate. |
| [STREAM-OOD](https://openaccess.thecvf.com/content/CVPR2026W/VAND/papers/Khalili_STREAM-OOD_Regime-Aware_Sequential_Monitoring_for_Streaming_Out-of-Distribution_Detection_CVPRW_2026_paper.pdf) and [supplement](https://openaccess.thecvf.com/content/CVPR2026W/VAND/supplemental/Khalili_STREAM-OOD_Regime-Aware_Sequential_CVPRW_2026_supplemental.pdf) | CVPRW 2026 | 1,440 hours/30 NYC intersections; 1.7 false alerts per normal hour on unseen locations. Scene/camera shifts, private data and controlled perturbations; unclear TTD frame/second conversion. Useful counterevidence, not a threat checkpoint. |
| [SmokeBench](https://openaccess.thecvf.com/content/WACV2026/html/Qi_SmokeBench_Evaluating_Multimodal_Large_Language_Models_for_Wildfire_Smoke_Detection_WACV_2026_paper.html) | WACV 2026 | Tested MLLMs struggled to localize small/early smoke. |
| [CADE](https://openaccess.thecvf.com/content/WACV2026/html/Hashimoto_CADE_Continual_Weakly-supervised_Video_Anomaly_Detection_with_Ensembles_WACV_2026_paper.html) | WACV 2026 | Continual weakly supervised adaptation; research lane rather than field validation. |
| [AnyAnomaly](https://openaccess.thecvf.com/content/WACV2026/html/Ahn_AnyAnomaly_Zero-Shot_Customizable_Video_Anomaly_Detection_with_LVLM_WACV_2026_paper.html) | WACV 2026 | Customizable LVLM pipeline with latency, foreground/background, and temporal limitations. |
| [ASK-HINT](https://openaccess.thecvf.com/content/WACV2026/html/Zou_Unlocking_Vision-Language_Models_for_Video_Anomaly_Detection_via_Fine-Grained_Prompting_WACV_2026_paper.html) | WACV 2026 | Fine-grained prompt recipe; explicitly static and without temporal modeling. |
| [VADER](https://openaccess.thecvf.com/content/WACV2026/html/Cheng_VADER_Towards_Causal_Video_Anomaly_Understanding_with_Relation-Aware_Large_Language_WACV_2026_paper.html) | WACV 2026 | Explanation/causal reasoning after upstream window selection. |
| [Regime-Aware VAD](https://openaccess.thecvf.com/content/CVPR2026W/VAND/html/Sasaki_From_Surveillance_to_Mobile_Robots_Regime-Aware_Video_Anomaly_Detection_CVPRW_2026_paper.html) | CVPRW 2026 | Feature preference changes sharply across target regimes; naïve fusion can be worse. |
| [Fine-VAD](https://openaccess.thecvf.com/content/CVPR2026/html/Zhang_Fine-VAD_Towards_Fine-Grained_Video_Anomaly_Detection_via_Progressive_Cross-Granularity_Learning_CVPR_2026_paper.html) | CVPR 2026 | Finer anomaly granularity without prospective deployment evidence. |
| [Alert-CLIP](https://openaccess.thecvf.com/content/CVPR2026/html/Zhu_Alert-CLIP_Abnormality-aware_Latent-Enhanced_Representation_Tuning_of_CLIP_for_Video_Anomaly_Detection_CVPR_2026_paper.html) | CVPR 2026 | Further language-guided VAD work; not a universal operating model. |
| [Benchmark AUC Is Not Deployable Reliability](https://arxiv.org/abs/2606.29506) | Unreviewed preprint | Cross-dataset and false-alarm corroboration only. |
| [Auditing Frame-Level AUC](https://arxiv.org/abs/2608.11985) | Unreviewed preprint | Metric-resolution and scene-bias warning. |
| [Frame-Level Evaluation Mostly Measures Video-Level Ranking](https://arxiv.org/abs/2608.21854) | Unreviewed preprint | Analytical warning about pooled micro-AUC. |

**2026 conclusion:** the reviewed artifacts do not establish a ready general threat checkpoint. STREAM-OOD does report held-out-location camera-hour evaluation, so a blanket claim that such evaluation does not exist is wrong. Its task, artifact gaps and alarm burden limit the product inference. Treat this as a bounded search result, not a universal negative proof.

</details>

<details>
<summary><strong>Operational deployments</strong></summary>

| Source | What it establishes | Limit |
|---|---|---|
| [TfL Smart Station full report](https://foi.tfl.gov.uk/FOI-3155-2324/Smart%20Station%20End%20of%20PoC%20Report_Redacted.pdf) | Existing station CCTV analyzed on an edge device across 11 use-case groups; real assistance/track-access detections and human decisions. | One station. Accurate litter alerts were operationally annoying; bicycle/scooter logic was disabled; weapon tests were staged. |
| [TfL use-case presentation](https://foi.tfl.gov.uk/FOI-3156-2324/Smart%20Station%20End%20of%20PoC%20Presentation_Redacted.pdf) | Detailed use-case and operational context. | Presentation evidence; interpreted alongside the final report. |
| [ALERTCalifornia technology](https://alertcalifornia.org/technology/) | More than 1,200 PTZ cameras and AI candidate alerts available to all 21 CAL FIRE dispatch centers; trained humans confirm. | Public success counts are not a controlled sensitivity/false-alarm study. |
| [DHS DeepZero assessment](https://www.dhs.gov/sites/default/files/2023-01/22_0818_st_deepzero.pdf) | Gun-detection workflow connected to existing CCTV/VMS and human verification. | Half-day staged test; multi-gun and lower-quality-camera failures; no vendor accuracy/FPR supplied. |

</details>

<details>
<summary><strong>Standards, security, and privacy</strong></summary>

| Source | Relevance |
|---|---|
| [ONVIF Profile T](https://www.onvif.org/profiles/profile-t/) | Practical IP-camera baseline: H.264/H.265, RTSP, events/metadata, HTTPS, and PTZ. |
| [Profile S deprecation](https://www.onvif.org/profiles/profile-s/profile-s-deprecation-qna/) | 31 March 2027 ends new product conformance submissions; existing conformant products can continue working. It is not a camera shutdown deadline. |
| [ONVIF specification history](https://www.onvif.org/profiles/specifications/specification-history/) | 2026 SRTP, media-signing/export, cloud-storage, and natural-language/image-search primitives. |
| [Profile V release-candidate announcement](https://www.onvif.org/pressrelease/onvif-releases-profile-v-draft/) | Proposed direct-cloud WSS, mTLS/tokens, WebRTC, encrypted storage, and events; not final. |
| [NIST SP 800-82 Rev. 3](https://csrc.nist.gov/pubs/sp/800/82/r3/final) | Network segmentation, zones, and permit-by-exception guidance applicable to camera estates. |
| [EDPB video-device guidance](https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices_en_0.pdf) | Specific purpose, necessity, minimization, and the boundary between video and biometric processing. |
| [Jordan Ministry PDPL FAQ](https://www.modee.gov.jo/EN/Pages/FAQs) | Jordanian data-protection baseline; biometric data is sensitive. |
| [EU AI Act](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=celex:32024R1689) | High-risk/prohibited-use context, especially remote biometric identification. Legal advice remains jurisdiction-specific. |

</details>

## Research method

The inherited discovery log records CVF CVPR/WACV 2026 title scans, scholarly indexes and citation chasing. This independent pass reread decisive papers and source, checked current releases/advisories, and searched surveillance/streaming work through 5 September 2026. It added STREAM-OOD and corrected model/benchmark and dependency claims. Rankings and snippets were discovery aids only; access gaps are recorded in the [audit](./audit.md).

Full papers and source were screened for peer-review status, CCTV/task fit, data provenance and staging, leakage, cross-site testing, operating-point metrics, baselines, latency boundaries, code/weight reproducibility, licensing, conflicts, and field evidence. Generic smart-city prose, vendor marketing without denominators, Medium/listicles, and industrial-image anomaly papers were excluded.

## Render locally

Open `architecture/architecture.html` directly in a browser: no server, install, CDN or network is needed. Select a component for its reuse boundary and source links; toggle internet availability and the first-capability view. The visualization is design documentation, not an implemented CCTV dashboard.

With [Typst](https://typst.app/open-source/) available, compile only to a temporary path:

```bash
typst compile report.typ /tmp/cctv-research-brief.pdf
```

The generated PDF is deliberately not tracked.

No license file is included: this is presently a private research repository, and no reuse grant is implied.
