#set document(title: "AI-Augmented CCTV Networks", author: "Technical research brief")
#set page(
  paper: "a4",
  margin: (x: 17mm, top: 15mm, bottom: 16mm),
  footer: context [
    #align(center)[#text(size: 7.5pt, fill: rgb("#708090"))[AI-Augmented CCTV Networks  •  #counter(page).display("1")]]
  ],
)
#set text(font: ("Liberation Sans", "DejaVu Sans"), size: 9pt, fill: rgb("#16212B"))
#set par(justify: true, leading: 0.62em)
#set list(indent: 13pt, body-indent: 5pt, spacing: 2.5pt)
#set enum(indent: 14pt, body-indent: 6pt, spacing: 3pt)
#set heading(numbering: "1.")
#show heading.where(level: 1): it => block(above: 14pt, below: 7pt)[
  #text(size: 16pt, weight: "bold", fill: rgb("#143D59"))[#it]
]
#show heading.where(level: 2): it => block(above: 10pt, below: 5pt)[
  #text(size: 11.5pt, weight: "bold", fill: rgb("#1D6285"))[#it]
]
#show heading.where(level: 3): it => block(above: 8pt, below: 4pt)[
  #text(size: 9.5pt, weight: "bold", fill: rgb("#245B74"))[#it]
]
#show link: set text(fill: rgb("#087E8B"))

#let navy = rgb("#143D59")
#let teal = rgb("#087E8B")
#let pale = rgb("#EAF4F4")
#let amber = rgb("#FFF3D6")
#let redpale = rgb("#FCEBEC")
#let rule = rgb("#CAD7DE")
#let callout(title, body, fill: pale, stroke: teal) = block(
  width: 100%, inset: 8pt, radius: 4pt, fill: fill, stroke: (left: 2.5pt + stroke)
)[
  #text(weight: "bold", fill: navy)[#title] #h(4pt) #body
]
#let tag(body, fill: navy) = box(fill: fill, radius: 3pt, inset: (x: 5pt, y: 2pt))[
  #text(size: 7pt, weight: "bold", fill: white)[#body]
]
#let smalltable(body) = text(size: 7.35pt)[#body]

#align(center + horizon)[
  #v(23mm)
  #text(size: 11pt, weight: "bold", tracking: 1.2pt, fill: teal)[TECHNICAL RESEARCH BRIEF]
  #v(8mm)
  #text(size: 30pt, weight: "bold", fill: navy)[AI-Augmented]
  #text(size: 30pt, weight: "bold", fill: navy)[CCTV Networks]
  #v(7mm)
  #line(length: 54mm, stroke: 2pt + teal)
  #v(8mm)
  #text(size: 13pt, fill: rgb("#435463"))[A buildable graduation project; a credible startup boundary]
  #v(20mm)
  #callout(
    [Decision],
    [Build a brownfield, edge-first *video-event engine*—not a cloud “threat AI.” The model is a detector + tracker + explicit rules, with narrow specialist verifiers and a person making safety-critical decisions.],
  )
  #v(18mm)
  #text(size: 9pt, fill: rgb("#607481"))[
    Prepared 5 September 2026  •  Evidence cutoff 4 September 2026
  ]
  #v(3mm)
  #text(size: 8pt, fill: rgb("#607481"))[
    Scope: retrofit existing CCTV/NVR estates; computer vision, open source, weights,
    field evidence, security and validation. Legal notes are product constraints, not legal advice.
  ]
]

#pagebreak()

= Executive decision

#callout(
  [The direct answer],
  [Yes, this is worth building. The useful first product is not general threat understanding; it is reliable camera onboarding, health monitoring, person/vehicle tracking, a few actionable site rules, evidence clips and operator feedback.],
)

The production chain is:

#align(center)[
  #table(
    columns: 9,
    inset: (x: 4pt, y: 6pt),
    stroke: none,
    fill: (x, y) => if calc.rem(x, 2) == 0 { pale },
    [*Camera / NVR*], [→], [*Restream + decode*], [→], [*Detect + track*], [→], [*Rules / verifier*], [→], [*Clip → human*],
  )
]

There is no defensible universal “threat detection model” ready to install. Start with *RTMDet-tiny → tracker → zone/line/dwell state machines*. Add one specialist only after target-site data exists. Generic video-anomaly detection (VAD) and vision-language models (VLMs) belong in shadow mode.

Run the data plane beside the cameras. Keep the customer’s NVR as recorder unless replacement is explicitly in scope. The hosted backend becomes an optional *control plane*: accounts, fleet health, configuration, alert delivery and signed model rollout. At an illustrative 4 Mbit/s per camera, eight uploaded feeds consume 32 Mbit/s continuously and about 345.6 GB/day.

== Product boundary

- Local service/appliance with a browser UI; a thin desktop shell is optional.
- Discover cameras, test credentials/streams, draw zones, install rule templates, display health, group event clips, and collect operator verdicts.
- One application password may unlock an encrypted vault; it cannot infer camera/NVR passwords. ONVIF multicast is normally local-segment only; analog feeds surface through a DVR/XVR; closed cloud cameras need vendor adapters.
- Outbound-only authenticated control connection; raw video stays local by default. Upload metadata or selected encrypted clips only when enabled.

#callout(
  [Graduation target],
  [A reproducible 4–8-camera edge overlay with honest cross-camera testing is a stronger thesis than inventing another benchmark-only anomaly network.],
  fill: amber,
  stroke: rgb("#E19B35"),
)

= Architecture

== Two coherent implementation paths

#smalltable[
  #table(
    columns: (1.05fr, 2fr, 2fr),
    inset: 5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Layer]], [#text(fill: white, weight: "bold")[Fastest MVP]], [#text(fill: white, weight: "bold")[Commercial direction]]),
    [Discovery], [Frigate/go2rtc ONVIF path + manual RTSP], [DL Streamer ONVIF suite; tested device/NVR adapters],
    [Media], [Embedded go2rtc + Frigate/FFmpeg], [MediaMTX as one media boundary],
    [Decode/CV], [Frigate pipeline; target substream], [DL Streamer/GStreamer hardware pipeline],
    [Perception], [Frigate detector path; inherited Norfair tracking], [RTMDet-tiny/s; benchmark ByteTrack; versioned rules],
    [Events], [Frigate review objects, clips, API/MQTT], [First-party schema, outbox, VMS/webhook adapters],
    [Serving], [In-process/local], [At most one: OVMS on Intel or Triton on NVIDIA, only when scale justifies it],
    [UI], [Forked local web UI], [First-party multi-site web control plane],
  )
]

Do not mix both paths into three media graphs and duplicated state. For the thesis, fork Frigate. For a cleaner startup core, own the event/configuration contract and separate media, CV, rules and control.

== Operational contract

The media router owns stream URLs; CV workers receive sampled/decoded frames; the rule engine consumes tracks; the control service owns configuration and secrets. A stable event envelope should contain:

#block(fill: rgb("#F3F6F8"), inset: 7pt, radius: 3pt)[
  #text(font: "DejaVu Sans Mono", size: 7.5pt)[event_id · tenant/site/camera_id · rule_id · class · confidence · track_id · zone · observed_at · severity · thumbnail/clip_ref · model/pipeline_version]
]

Start with an authenticated HTTPS outbox. Add MQTT only for integrations. Instrument reconnects, input/output FPS, decoder errors, dropped frames, inference queues/latency, alerts, storage and upload backlog.

== Security is architecture

#callout(
  [Release blocker],
  [Frigate stable must not be shipped untouched. GHSA-c4qf-xxq4-vf55 lists no patched release; source inspection found v0.17.2 still permits any authenticated user to access service logs. RC/development restricts logs to admins, but camera passwords and credentialed RTSP URLs still travel in GET query strings. Convert probes to POST bodies, redact every logging path, rotate test credentials, add regression tests and commission review.],
  fill: redpale,
  stroke: rgb("#B94A55"),
)

Bind go2rtc to the authenticated application boundary: its LAN defaults can expose streams and dangerous API functionality. MediaMTX defaults allow anonymous publish/read. OVMS supplies neither access control nor transport encryption; Triton assumes a trusted network and loads unsandboxed model/backend code. Never expose these services directly.

Put cameras on a restricted VLAN with no Internet, use per-camera low-privilege accounts, cap hostile media inputs, pin decoder/container builds, deny traffic by default, and avoid inbound port forwarding. See #link("https://csrc.nist.gov/pubs/sp/800/82/r3/final")[NIST SP 800-82r3].

= Open-source composition

All shortlisted repositories were cloned and inspected locally; authoritative upstream links and decisions are catalogued in the repository README.

#smalltable[
  #table(
    columns: (1.15fr, 1.55fr, 2.6fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Component]], [#text(fill: white, weight: "bold")[Decision]], [#text(fill: white, weight: "bold")[Reason / constraint]]),
    [#link("https://github.com/blakeblackshear/frigate")[Frigate 0.17.2]], [*MVP fork*], [MIT code; excellent integrated NVR/UI/rules base. Replace proprietary brand assets and fix credential/log paths first. 0.18 was RC, not stable.],
    [#link("https://github.com/AlexxIT/go2rtc")[go2rtc 1.9.14]], [*Use inside Frigate*], [MIT; broad restream/playback support. Do not run a second copy. Lock down API/RTSP and modules.],
    [#link("https://github.com/bluenviron/mediamtx")[MediaMTX 1.20.1]], [*Startup media plane*], [MIT; pull once/fan out, playback, hooks, OpenAPI and metrics. Harden anonymous defaults.],
    [#link("https://github.com/open-edge-platform/dlstreamer")[DL Streamer 2026.1]], [*Startup Intel edge*], [MIT; GStreamer/OpenVINO decode, discovery, inference, tracking and rules. Test 2026.2: its published release body was future-dated.],
    [#link("https://ffmpeg.org/")[FFmpeg 9.0.1]], [*Use/pin*], [LGPL-2.1+ by default; GPL/nonfree configure flags change redistribution rights. Record the actual build.],
    [MMDetection / MMPose / MMAction2], [*Training lab*], [Apache-2.0 code; export lean artifacts. Dataset and checkpoint rights remain separate.],
    [#link("https://github.com/ifzhang/ByteTrack")[ByteTrack]], [*Standalone candidate*], [MIT; simple low-score association. Benchmark against inherited Frigate/Norfair before replacing it.],
    [OVMS / Triton], [*Later, choose one*], [KServe-compatible serving; Apache-2.0 / BSD-3. Too much operational surface for one box.],
    [Supervision / Viseron], [*Experiment / reference*], [Useful, permissive projects; avoid a second overlapping runtime.],
    [#link("https://github.com/ZoneMinder/zoneminder")[ZoneMinder 1.38.4]], [*Existing-VMS adapter*], [Mature NVR/events/API, but GPL-2.0 and a coupled C++/Perl/PHP/MariaDB stack. Stable ONVIF is labeled experimental; AI comes from companion projects.],
  )
]

*Clone does not equal permission.* Code, weights and data can carry different terms. A repository with no license grants no reuse permission. Avoid Ultralytics in a closed product unless AGPL obligations or a commercial license are consciously accepted. One inspected fire repository labels its root MIT while vendoring GPL-3.0 YOLOv5 files; reject it as a shipping dependency.

ZoneMinder’s current AI route is *zmeventnotificationNg → pyzmNg → YOLO/ONNX*, triggered from NVR events. It is useful for customers already running ZoneMinder, but its 7.0 event server calls itself development software and the principal components are GPL. Integrate through streams/APIs; do not inherit the whole runtime.

== 2026 infrastructure findings

- ONVIF 26.06 added SRTP configuration, media-signing export, cloud-segment listing/export, encrypted-storage capabilities, and natural-language/image recording search. #link("https://www.onvif.org/profiles/specifications/specification-history/")[Specification history].
- July’s *Profile V release candidate* proposes camera-initiated WSS, mTLS/tokens, WebRTC, encrypted object storage and event transport. It is not final and device support will lag. #link("https://www.onvif.org/pressrelease/onvif-releases-profile-v-draft/")[ONVIF announcement].
- Profile T remains the practical baseline for H.264/H.265, RTSP, events/metadata, HTTPS and PTZ. Profile S support ends 31 March 2027 because its mandatory authentication is obsolete. #link("https://www.onvif.org/profiles/profile-t/")[Profile T] · #link("https://www.onvif.org/profiles/profile-s/profile-s-deprecation-qna/")[S deprecation].

= Events and models

Detect operationally defined events, not “suspicion.” Priority follows observability, labelability, consequence and whether an operator can act.

#smalltable[
  #table(
    columns: (1.35fr, 2.25fr, 1.35fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Event]], [#text(fill: white, weight: "bold")[Mechanism / caveat]], [#text(fill: white, weight: "bold")[Verdict]]),
    [Offline/frozen/covered/blurred], [Telemetry, hashes, blur/exposure/scene statistics; ONVIF tamper where present], [#tag([SHIP FIRST], fill: teal)],
    [Restricted-zone intrusion], [Person/vehicle + track + polygon + schedule + persistence], [#tag([SHIP FIRST], fill: teal)],
    [Line crossing / wrong way], [Track trajectory + direction/class + minimum age], [#tag([SHIP FIRST], fill: teal)],
    [Dwell / stopped vehicle], [Track dwell with occlusion grace; call it dwell, not inferred intent], [#tag([SHIP FIRST], fill: teal)],
    [Occupancy / queue], [Smoothed counts; density and occlusion limits], [#tag([GOOD VERTICAL], fill: rgb("#427AA1"))],
    [Person down / fall], [Pose + temporal state/classifier; staged unseen-site evaluation], [#tag([PILOT], fill: rgb("#D28A1A"))],
    [Smoke / fire], [Dedicated detector + temporal persistence/growth; never replace certified sensors], [#tag([SEPARATE VERTICAL], fill: rgb("#D28A1A"))],
    [Abandoned object], [Stationary item + track/owner-distance history], [#tag([LATER], fill: rgb("#7D8491"))],
    [Collision], [Temporal change + vehicle interaction + specialist], [#tag([LATER], fill: rgb("#7D8491"))],
    [Visible weapon], [Tiny-object crops/tiling + multi-frame confirmation + person], [#tag([ADVISORY ONLY], fill: rgb("#A84855"))],
    [Fight / aggression], [Temporal specialist; subjective labels and staged/balanced data], [#tag([ADVISORY ONLY], fill: rgb("#A84855"))],
    [Generic anomaly / suspiciousness], [VAD/VLM score cannot define site policy or alarm budget], [#tag([SHADOW ONLY], fill: rgb("#A84855"))],
    [Face ID / emotion], [Biometric/affect inference unnecessary to the wedge], [#tag([EXCLUDE], fill: rgb("#822F3A"))],
  )
]

== The model, concretely

Begin with *RTMDet-tiny*. The saved 60.1 MB COCO checkpoint is SHA-256 hashed in the manifest. Its paper’s 0.98 ms claim is RTX 3090 model-only FP16 latency excluding NMS—not decoded multi-camera throughput. Fine-tune on target-camera people/vehicles. Test RTMDet-small only if the box has headroom. Use ByteTrack in a standalone pipeline or retain Frigate’s Norfair until target evidence favors replacement.

Specialists run only on candidate clips:

- *Fall:* crop a tracked person → RTMPose keypoints → short temporal classifier/rules → abstain when pose quality is poor. UR Fall has only 30 falls and 40 daily-activity sequences and is non-commercial CC BY-NC-SA.
- *Fight:* X3D-XS is merely a temporal backbone. RWF-2000’s 2,000 balanced, trimmed YouTube/CCTV clips do not estimate false alerts in a mostly uneventful stream; commercial data rights are unclear.
- *Fire/smoke:* fine-tune the base detector on audited fixed-camera data, then require persistence/growth and human/sensor confirmation. D-Fire is a useful CC0 image seed, not a live camera-hour test.
- *Weapon:* #link("https://arxiv.org/abs/2303.10703")[CCTV-Gun] reports UCF handguns averaging 16 pixels and cross-dataset AP50 of only 3.7–7.7 in key settings. Measure pixels-on-target before promising anything; tile high-resolution crops and require temporal/human confirmation.

Open-vocabulary models stay off the hot path. The downloaded 694 MB GroundingDINO checkpoint and Florence-2-base are useful for offline annotation or crop verification. Qwen2.5-VL-7B is Apache-2.0, but its smaller 3B sibling is non-commercial—model-family names do not imply one license. #link("https://doi.org/10.1609/aaai.v39i4.32463")[MHBench] documents motion hallucination in VideoLLMs.

= Computer-vision evidence

== Why benchmark scores do not ship

Public VAD datasets—UCF-Crime, ShanghaiTech, Avenue, UCSD Ped2, Street Scene, RWF-2000, NWPU Campus and XD-Violence—made the field possible. They also mix staged events, web/movie footage, few scenes, coarse labels and evaluation distributions unlike a new camera estate. AUROC averages thresholds no operator would tolerate.

- #link("https://openaccess.thecvf.com/content/CVPR2021/html/Hasan_Generalizable_Pedestrian_Detection_The_Elephant_in_the_Room_CVPR_2021_paper.html")[CVPR 2021] found even task-specific pedestrian detectors degrade under modest dataset shift.
- #link("https://openaccess.thecvf.com/content/WACV2022/html/Doshi_Rethinking_Video_Anomaly_Detection_-_A_Continual_Learning_Approach_WACV_2022_paper.html")[WACV 2022] challenged the assumption that training contains every normal pattern.
- A #link("https://openaccess.thecvf.com/content/CVPR2024W/ABAW/html/Yao_Evaluating_the_Effectiveness_of_Video_Anomaly_Detection_in_the_Wild_CVPRW_2024_paper.html")[2024 unseen-camera study] found ShanghaiTech-trained VAD models near chance on CHAD cameras.
- Real-time WSVAD work still needed 6.4 seconds of evidence plus 0.5 seconds processing, and removed UCF clip edges because banners became anomaly cues.

Target cameras add compression, darkness, insects, weather, reflections, shake, occlusion and new “normal.” Treat AUC/mAP as research filters. Product evidence is event-level performance, fixed thresholds and nuisance alerts per camera-day on held-out cameras/sites.

== The 2026 contribution

#smalltable[
  #table(
    columns: (1.25fr, 1.65fr, 2.4fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Work]], [#text(fill: white, weight: "bold")[Contribution]], [#text(fill: white, weight: "bold")[Product reading]]),
    [#link("https://openaccess.thecvf.com/content/CVPR2026/html/Acharya_The_Road_Less_Seen_Segment_Exploration_for_Weakly_Supervised_Video_CVPR_2026_paper.html")[Road Less Seen]], [Low-FPR metrics; diverse segment exploration], [VadCLIP recall 0.109 at 1% FPR; InternVL3-14B 0.301; proposed fusion 0.173. At 5% FPR, >50k false segments. Its evaluation lesson matters more than its architecture.],
    [#link("https://openaccess.thecvf.com/content/CVPR2026/html/Dai_No_Need_For_Real_Anomaly_MLLM_Empowered_Zero-Shot_Video_Anomaly_CVPR_2026_paper.html")[LAVIDA]], [MLLM semantics + pseudo anomalies + spatial learning], [Strong reported AUC/AP across five benchmarks, but no camera-day point. Repo had incomplete instructions and no trained LAVIDA checkpoint. Code ≠ usable weights.],
    [#link("https://openaccess.thecvf.com/content/CVPR2026W/AUTOPILOT/html/Picek_ACCIDENT_A_Benchmark_Dataset_for_Vehicle_Accident_Detection_from_Traffic_CVPRW_2026_paper.html")[ACCIDENT]], [2,027 real + 2,211 synthetic CCTV traffic clips], [Qwen2.5-VL-7B 0.115 and Molmo-7B 0.271 collision accuracy, below 0.335 majority; DINOv2 sim→real probe 0.440 vs human 0.923. Domain supervision beats prompting.],
    [#link("https://openaccess.thecvf.com/content/WACV2026/html/Qi_SmokeBench_Evaluating_Multimodal_Large_Language_Models_for_Wildfire_Smoke_Detection_WACV_2026_paper.html")[SmokeBench]], [MLLM wildfire smoke recognition/localization], [All tested models struggled on small/early smoke localization; apparent positive accuracy could coexist with bad negative behavior. Use a dedicated temporal model.],
    [CADE / AnyAnomaly / ASK-HINT / VADER], [Continual learning; custom prompts; causal explanations], [Useful experiment lane. AnyAnomaly has no own checkpoint; ASK-HINT has no temporal model; VADER depends on upstream window selection.],
    [Three 2026 arXiv audits], [Cross-dataset and AUC failure analyses], [Convergent warning only: unreviewed. Title-only/unavailable ECCV entries were excluded.],
  )
]

#callout(
  [2026 verdict],
  [No 2026 surveillance checkpoint found was simultaneously downloadable, reproducible, commercially explicit, and evaluated by held-out-site camera-hour false alarms. The year’s most useful advance is better criticism of evaluation—not a production “threat brain.”],
  fill: amber,
  stroke: rgb("#E19B35"),
)

= Field evidence

Only technical/official material that establishes operation is included; deployment is not equated with efficacy.

#smalltable[
  #table(
    columns: (1.15fr, 2.2fr, 2.15fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Case]], [#text(fill: white, weight: "bold")[Established]], [#text(fill: white, weight: "bold")[Not established]]),
    [#link("https://foi.tfl.gov.uk/FOI-3155-2324/Smart%20Station%20End%20of%20PoC%20Report_Redacted.pdf")[TfL, Willesden Green]], [One-station edge PoC, Oct 2022–Sep 2023, 11 use-case groups and ~44k triggers. It found falls/assistance and track access; >300 alerts caused extra yellow-line announcements. Humans decided; no face/audio.], [Litter was accurate but disabled because alert volume annoyed staff; bicycles/scooters caused false alerts; weapons were after-hours staged tests. The 1% operator-marked-invalid figure is not measured FPR.],
    [#link("https://alertcalifornia.org/technology/")[ALERTCalifornia + CAL FIRE]], [>1,200 PTZ cameras; candidate AI alerts available to all 21 CAL FIRE dispatch centers since Sep 2023. Trained watchstanders confirm them.], [Public successes are not a controlled sensitivity/false-alarm study. This proves a narrow, high-value human-loop design.],
    [#link("https://www.dhs.gov/sites/default/files/2023-01/22_0818_st_deepzero.pdf")[DHS/NYPD DeepZero test]], [Gun detector linked to existing CCTV/VMS; frames went to a 24/7 human verification center; interface was usable.], [Half-day mock block. Missed simultaneous guns, struggled on poorer cameras, excluded concealed/holstered guns; vendor gave no accuracy/FPR. Design evidence, not field efficacy.],
  )
]

The robust pattern is *narrow detector + human confirmation + concrete response*. TfL adds the decisive product lesson: an accurate trigger can still be useless when it interrupts staff too often.

= Validation plan

Use public data to initialize, never certify. Collect authorized target footage across cameras, day/night/weekend, weather and long uneventful periods; safely stage positives. Split by camera and date. Adjacent clips from one source never cross train/test boundaries.

== Required measures

- Event-level precision, recall and 95% confidence intervals—not only frame mAP/AUC.
- Nuisance alerts per camera-day, with a cause taxonomy.
- Detection-to-notification p50/p95 latency.
- Stream/inference uptime, dropped frames, compute, memory, thermals and power.
- Performance by camera, light, weather, distance, occlusion and event subtype.
- Operator acknowledgement, disposition time and overrides.

Suggested pilot gates—*product targets, not literature facts*: ≥90% recall on predeclared staged intrusion/line events; ≤1 nuisance alert/camera-day/enabled rule after calibration; p95 notification under 3 s; ≥99% seven-day pipeline availability; no continuous cloud video by default. Specialists need separate, stricter customer-approved gates and mandatory human confirmation.

== Twelve weeks

#smalltable[
  #table(
    columns: (0.7fr, 1.4fr, 3.5fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Weeks]], [#text(fill: white, weight: "bold")[Work]], [#text(fill: white, weight: "bold")[Exit evidence]]),
    [1–2], [Ingest + security], [Fork Frigate 0.17.2; fix credential/log flows; discovery + RTSP fallback; vault; main/substreams; health; clip extraction.],
    [3–4], [Perception + rules], [RTMDet on target box; tracker; polygons, lines, schedules, persistence, direction, dwell, hysteresis/cooldown.],
    [5–6], [Operations], [Event DB, deduplication, evidence clips, acknowledgement/verdicts, audit/webhook; inject stream loss, bad timestamps and reboot.],
    [7–8], [Specialist + shadow], [One specialist only if data/rights exist. One 2026 VAD model runs silently for comparison—never paging.],
    [9–10], [Data campaign], [Long negatives + safely staged positives across conditions; camera/date-separated frozen split.],
    [11–12], [Blind pilot + thesis], [Event metrics, camera-day burden, latency, uptime, hardware cost and failure taxonomy—including failures in the demo.],
  )
]

= Startup boundary, privacy and research quality

== Commercial thesis

The wedge is reliable retrofit for one vertical—warehouses, campuses or small multi-site operators—not a generic surveillance platform. Sell fewer unattended cameras and less manual review. The moat is tested device adapters, target-domain data, calibration, alert-quality operations, human feedback, failure observability and trusted rollout; public detector weights are not a moat.

Exclude face and emotion recognition. Jordan’s Personal Data Protection Law No. 24 of 2023 has been effective since 17 March 2024 and treats biometric data as sensitive (#link("https://www.modee.gov.jo/EN/Pages/FAQs")[Ministry FAQ]). European guidance demands a specific purpose, necessity and minimization; ordinary video becomes biometric processing when technically used for unique identification (#link("https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices_en_0.pdf")[EDPB guidance]). Determine controller/processor roles, signage, retention, access, export, deletion and incident response with local counsel.

== Paper discovery and quality screen

Discovery used complete CVF CVPR/WACV 2026 proceedings-title scans, DBLP, OpenAlex/Crossref, arXiv, official project pages, GitHub/Hugging Face cards, and backward/forward citation chasing. No account is currently needed. Semantic Scholar’s API key is optional; IEEE/ACM institutional access matters only if a decisive paper is paywalled.

A paper entered the evidence base only when the full text was retrievable and it contributed an influential protocol/dataset, reproducible model, direct cross-domain/online evidence, or deployment-relevant failure analysis. Screening checked:

#columns(2, gutter: 8mm)[
- peer-review/venue status;
- CCTV/task fit;
- data origin, staging and prevalence;
- split leakage and site separation;
- cross-dataset/online tests;
- realistic operating points;
- baselines and ablations;
- compute/latency boundaries;
- code/weight reproducibility;
- code, checkpoint and data rights;
- independent field evidence;
- contradictions and missing denominators.
]

Industrial image anomalies, generic “smart city” papers, vendor cases without denominators, SEO pages, Medium and generated summaries were excluded. Search snippets were discovery hints only. Government reports establish operations but may lack counterfactuals; peer review establishes research scrutiny, not product reliability.

Access gaps retained as gaps: the D-Fire device paper was paywalled, MUVIM needs email/waiver access, i-LIDS was withdrawn, and several gun/VAD checkpoints lack standalone commercial terms. None justifies creating an account yet.

#callout(
  [Bottom line],
  [Use a security-hardened Frigate fork for the MVP. Use RTMDet-tiny + measured tracking + explicit rules as the model stack. For a commercial Intel edge core, favor DL Streamer/GStreamer + MediaMTX + a first-party control/event service. Keep VAD/VLMs in shadow mode. Make alert quality, system health and human decisions the product.],
)

#v(4mm)
#text(size: 7.5pt, fill: rgb("#607481"))[
  Evidence catalog: authoritative links, review status and adoption decisions are maintained in the repository README. Bulk clones, papers, model checkpoints and rendered artifacts were intentionally excluded from version control.
]
