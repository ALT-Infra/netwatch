#set document(title: "netwatch", author: "Technical research brief")
#set page(
  paper: "a4",
  margin: (x: 17mm, top: 15mm, bottom: 16mm),
  footer: context [
    #align(center)[#text(size: 7.5pt, fill: rgb("#708090"))[netwatch  •  #counter(page).display("1")]]
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
#let smalltable(body) = {
  set table.cell(breakable: false)
  text(size: 7.35pt)[#body]
}

#align(center + horizon)[
  #v(23mm)
  #text(size: 11pt, weight: "bold", tracking: 1.2pt, fill: teal)[TECHNICAL RESEARCH BRIEF]
  #v(8mm)
  #text(size: 30pt, weight: "bold", fill: navy)[netwatch]
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
    Independently reviewed 5 September 2026  •  Evidence cutoff 5 September 2026
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

The reviewed evidence does not establish a reproducible, commercially cleared, general-purpose threat checkpoint with acceptable held-out-site alarm behavior. Start with a *supported detector → inherited tracker → one person-in-zone rule → reviewable incident*. RTMDet is a replacement candidate, not a settled winner. Generic video-anomaly detection (VAD), vision-language models (VLMs) and specialists remain separate experiments until target-site evidence supports them.

Run the data plane beside the cameras. Keep the customer’s NVR as recorder unless replacement is explicitly in scope. The hosted backend becomes an optional *control plane*: accounts, fleet health, configuration, alert delivery and signed model rollout. At an illustrative 4 Mbit/s per camera, eight uploaded feeds consume 32 Mbit/s continuously and about 345.6 GB/day.

== Product boundary

- Local service/appliance with a browser UI; a thin desktop shell is optional.
- Discover cameras, test credentials/streams, draw zones, install rule templates, display health, group event clips, and collect operator verdicts.
- Application credentials cannot infer camera/NVR passwords. ONVIF multicast is normally local-segment only; analog feeds surface through a DVR/XVR; closed cloud cameras need vendor adapters. Use a narrowly supported device/OS/driver matrix first. Camera discovery is an aid, not guaranteed zero-configuration installation.
- Outbound-only authenticated control connection; raw video stays local by default. Upload metadata or selected encrypted clips only when enabled.

#callout(
  [Graduation target],
  [Prove one camera end to end, then scale toward 4–8 only after measuring decode, inference, evidence storage and operator burden on the actual box. Camera count is a workload target, not a validated capacity.],
  fill: amber,
  stroke: rgb("#E19B35"),
)

= Architecture

== Where to build the foundation

#smalltable[
  #table(
    columns: (1.05fr, 2fr, 2fr),
    inset: 5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Approach]], [#text(fill: white, weight: "bold")[Work saved]], [#text(fill: white, weight: "bold")[Work owned / decision]]),
    [Controlled Frigate fork], [Media workers, recording/index, tracker/zones, review lifecycle and React/FastAPI UI], [*Choose.* Own a distinct incident/policy module, security patches and packaging; preserve upstream history.],
    [Service beside stock Frigate], [Working appliance through HTTP/MQTT], [Useful for installed customers; cannot fix internal security or supply full track histories just through a wrapper.],
    [Own core + MediaMTX/FFmpeg], [Media routing, recording and codec primitives], [Own supervision, clocks, retention, event lifecycle, auth and UI. Credible fallback if fork costs or measured requirements justify it.],
    [DL Streamer/GStreamer], [Intel hardware pipeline and analytics elements], [Possible replacement CV worker; not the complete local product. GstAnalytics still needs an adapter into our contract.],
    [Viseron / ZoneMinder], [Other actual NVR foundations], [Viseron is a viable MIT comparison; no demonstrated scope advantage. ZoneMinder is valuable as an installed VMS adapter, with a deliberate GPL choice.],
  )
]

*The foundation exists, but the product does not yet.* Preserve the expensive Frigate internals; borrow or adapt specific algorithms from other projects only when they improve a measured outcome. Modifying code is expected. Missing plug compatibility is not evidence against reuse. Keep our incident identity, policy versions, verdicts and later outbound queue in distinct modules, initially within the same application/database. A microservice split is unnecessary.

This choice is an engineering judgment, not a timed comparison. It remains the commercial path unless maintenance cost, independent scaling or a required media/CV feature justifies replacing a boundary. There is no evidence for an inevitable full rewrite. Select *one* restream owner: embedded go2rtc now; MediaMTX only if replacing that boundary. Source pins, alternatives and release obligations are in the local audit. The interactive #link("architecture/architecture.html")[system map] distinguishes retained, adapted and new code.

== Trace one stream

+ *Enroll:* the operator supplies camera/NVR credentials; same-segment WS-Discovery uses UDP 3702, then ONVIF SOAP GetProfiles/GetStreamUri over HTTP(S), or a manually verified RTSP URL. NVR PoE ports may be isolated behind an internal subnet: obtain an authorized NVR channel stream or a routed camera path. No assumption of universal playback access.
+ *Pull:* the edge initiates RTSP control and receives compressed H.264/H.265 over negotiated RTP, initially TCP interleaving. go2rtc fans out each configured source. Main and substreams are separate upstream sessions; the existing NVR may hold another. Probe connection limits, GOP, timestamps and codecs.
+ *Split before inference:* compressed main video goes to Frigate/FFmpeg recording segments and a bounded local evidence window. Substream video is decoded, sampled, motion/region selected, resized and passed to the detector. Motion gating reduces inference work, not necessarily decode work, and can hide motionless or slowly moving targets.
+ *Perceive and decide:* detector boxes/scores feed Norfair, then bottom-center zone membership. Product logic turns a qualifying transition into one incident. Line/direction/schedule extensions must specify time, reset and gap semantics; a score is not an incident or a calibrated probability of danger.
+ *Persist and review:* one writer commits incident metadata and evidence references. Evidence starts pending, becomes playable after post-roll/segment completion, or becomes explicitly missing. The local desktop browser gets HTTPS API/media and WSS event updates; RTSP is not a browser playback format. Start with H.264; test H.265/browser/hardware combinations or budget transcoding.
+ *Optionally deliver outward:* an edge-initiated authenticated TLS session carries allowlisted event metadata/health and, only when separately enabled, selected clips/thumbnails. Configuration and signed updates return on that connection, subject to local validation and rollback. It is not a camera tunnel. Remote playback of local-only evidence requires an explicitly authorized connection; a cloud notification alone does not provide it.

The edge is a second, bounded evidence recorder while the NVR remains the archive. Configure local pre/post-roll retention rather than assuming every NVR can export a matching clip. At 4 Mbit/s, one hour of main video is about 1.8 GB, excluding overhead; eight cameras need about 14.4 GB/hour. Disk pressure must visibly expire/miss evidence, never pretend the clip is available. NVR survival depends on its own power/network/storage; a UPS is a separate deployment choice.

== Operational contract

The media router owns stream URLs; CV workers receive sampled/decoded frames; the rule engine consumes tracks; the control service owns configuration and secrets. A stable event envelope should contain:

#block(fill: rgb("#F3F6F8"), inset: 7pt, radius: 3pt)[
  #text(font: "DejaVu Sans Mono", size: 7.5pt)[event_id · tenant/site/camera_id · rule_id · class · confidence · track_id · zone · observed_at · severity · thumbnail/clip_ref · model/pipeline_version]
]

Extend that envelope with schema version, camera epoch, rule/config hash, source PTS, local observed/qualified/committed times, incident state, evidence state and operator verdict. Track IDs are local and temporary; restart/reconnect must not join unrelated trajectories. Use monotonic time for duration and wall-clock time for display/correlation. Main/substream offsets need measurement.

Instrument decoded-frame age separately from RTSP connectivity, plus recording and inference health. Bounded queues favor current frames; report drops and blind time. Keep local login, rules and storage independent of cloud identity. An Internet outage preserves LAN viewing, inference, recording and local incident updates while the box and LAN work. Native WebPush depends on browser-provider infrastructure; remote push/email and hosted management are unavailable. A later durable outbox retries with event IDs, bounded storage and expiry; it must not send an obsolete alarm storm after recovery. MQTT is optional integration transport, not the authoritative incident store.

== Security is architecture

#callout(
  [Release blocker],
  [The proposed base is Frigate v0.17.2 plus a reviewed patch set and refreshed media builds, not its stock image. Stable source retains viewer-readable logs and query-string credentials, generic authorization on static media paths, and user-controlled regex execution on the database worker. Review the latest stable state when coding starts; a prerelease label does not establish security.],
  fill: redpale,
  stroke: rgb("#B94A55"),
)

The #link("https://github.com/blakeblackshear/frigate/security/advisories/GHSA-c4qf-xxq4-vf55")[log advisory] names 0.17.1/no patch; continued 0.17.2 exposure is a separate source finding. The #link("https://github.com/blakeblackshear/frigate/security/advisories/GHSA-74x4-gw64-2mq5")[media ACL advisory] lists all versions/no patch. The #link("https://github.com/blakeblackshear/frigate/security/advisories/GHSA-q8jx-q884-jcq9")[regex advisory] lists ≤0.17.2 and a beta3 patch. Fix/redact credential flows, authorize every evidence path, disable directory listing/public caching, and remove or safely replace unsupported regex filters. Role/stream/probe regression checks are required before a pilot.

Bind go2rtc to the authenticated application boundary: its LAN defaults expose streams and potentially executable source types. Keep unauthenticated Frigate/internal media ports private; limit command/source schemes and camera destinations. An encrypted credential file with a key beside it does not resist host root; choose a protected mounted secret or OS-backed key store with explicit unattended-restart behavior. Restrict accounts and isolate hostile decoders. MediaMTX anonymous defaults and OVMS/Triton exposure are concerns only if those optional components are selected; see #link("audit.md")[source audit].

Put cameras on a restricted VLAN with no Internet, use per-camera low-privilege accounts, cap hostile media inputs, pin decoder/container builds, deny traffic by default, and avoid inbound port forwarding. See #link("https://csrc.nist.gov/pubs/sp/800/82/r3/final")[NIST SP 800-82r3].

= Open-source composition

The local research includes cloned source, papers and manifests. The independent review rechecked the decision-driving interfaces, release pins and security paths; it did not execute the CCTV pipeline. Authoritative links, maintenance dates and limits are in the README and audit.

#smalltable[
  #table(
    columns: (1.15fr, 1.55fr, 2.6fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Component]], [#text(fill: white, weight: "bold")[Decision]], [#text(fill: white, weight: "bold")[Reason / constraint]]),
    [#link("https://github.com/blakeblackshear/frigate")[Frigate 0.17.2]], [*MVP fork*], [MIT code; excellent integrated NVR/UI/rules base. Replace proprietary brand assets and fix credential/log paths first. 0.18 was RC, not stable.],
    [#link("https://github.com/AlexxIT/go2rtc")[go2rtc]], [*Retain embedded*], [MIT. Frigate stable bundles 1.9.10, not latest 1.9.14. Audit upgrades; 1.9.14 has a disclosed RTSP parser issue.],
    [#link("https://github.com/bluenviron/mediamtx")[MediaMTX 1.20.1]], [*Alternative media owner*], [MIT; routing, recording/playback, hooks and metrics. Not part of the selected fork. Harden anonymous defaults.],
    [#link("https://github.com/open-edge-platform/dlstreamer")[DL Streamer 2026.1]], [*Alternative Intel worker*], [MIT; GStreamer/OpenVINO and analytics. Pin tested OS/kernel/driver combinations. 2026.2 publication/body dates conflict.],
    [#link("https://ffmpeg.org/")[FFmpeg]], [*Retain; refresh builds*], [Latest inspected 9.0.1 is not bundled. Frigate stable downloads GPL 7.0.2 and 5.1 builds. Audit exact binaries and redistribution obligations.],
    [MMDetection / MMPose / MMAction2], [*Training candidates*], [Apache-2.0 code, separate weight/data rights. MMDetection head remains Feb 2024 with old MMCV bounds; own environment maintenance.],
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
- Prefer Profile T for new compatible devices, while testing each device's supported/conditional H.264/H.265, transport, metadata and PTZ capabilities. It is not a blanket encryption guarantee. Profile S's 31 March 2027 deadline ends *new product conformance submissions*; existing conformant devices can continue working. Digest/TLS security depends on the actual device/client. #link("https://www.onvif.org/profiles/profile-t/")[Profile T] · #link("https://www.onvif.org/profiles/profile-s/profile-s-deprecation-qna/")[S deprecation].

= Events and models

Detect operationally defined events, not “suspicion.” Priority follows observability, labelability, consequence and whether an operator can act.

#smalltable[
  #table(
    columns: (1.35fr, 2.25fr, 1.35fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Event]], [#text(fill: white, weight: "bold")[Mechanism / caveat]], [#text(fill: white, weight: "bold")[Verdict]]),
    [Stream liveness], [Decoded-frame age, source/decoder and recorder state; connection alone is insufficient], [#tag([FIRST SLICE], fill: teal)],
    [Frozen/covered/blurred], [Image statistics can confuse a static scene, night, fog or focus; calibrate separately], [#tag([LATER HEALTH], fill: rgb("#D28A1A"))],
    [Restricted-zone presence], [Person + inherited track/polygon + persistence; no inferred authorization or intent], [#tag([FIRST SLICE], fill: teal)],
    [Line crossing / wrong way], [Finite-line trajectory intersection + signed direction + age/hysteresis; reset on gaps], [#tag([NEXT RULES], fill: rgb("#427AA1"))],
    [Dwell / stopped vehicle], [Monotonic dwell timer with occlusion grace and reset policy; not inferred intent], [#tag([NEXT RULES], fill: rgb("#427AA1"))],
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

Begin with Frigate's already-supported *OpenVINO SSDLite MobileNet v2 COCO* path on a supported Intel Linux PC; it is a reproducible baseline, not the presumed best model. Keep Norfair. First validate person detection at the actual camera angle and distance; the fallback CPU run demonstrates one-camera correctness, not multi-camera capacity. Check the exact checkpoint terms before distribution.

*RTMDet-tiny* remains a serious training/export challenger. Its saved 60.1 MB checkpoint was hashed, not executed. Its #link("https://github.com/open-mmlab/mmdetection/blob/cfd5d3a985b0249de009b67d04f37263e11cdf3d/configs/rtmdet/README.md")[0.98 ms benchmark] is TensorRT FP16 on RTX 3090, batch 1, without NMS. Frigate v0.17.2's #link("https://github.com/blakeblackshear/frigate/blob/v0.17.2/frigate/detectors/plugins/openvino.py")[plugin] has no RTMDet decoder. An adapter must match resize/color/layout, output decoding, NMS, class mapping, coordinates and its fixed 20-box output; ONNX export alone is insufficient. Measure export/reference parity, target recall, false incidents and full-pipeline latency before replacing the baseline.

ByteTrack's association algorithm is reusable MIT code, but its upstream head remains December 2022 and requirements pin old ONNX runtimes; MMDetection head remains February 2024. Borrow the needed algorithm into a maintained environment, preserving notices, rather than importing an entire research stack. Norfair replacement needs an ID continuity/rule-error comparison, not only a MOT benchmark. These are maintenance costs, not automatic rejections.

Specialists normally run on candidate clips. The gate must observe the target: a person/vehicle gate cannot establish smoke coverage or detect events missed upstream. Measure gate recall separately; an independent low-rate smoke/scene branch may be needed for that later vertical.

- *Fall:* crop a tracked person → RTMPose keypoints → short temporal classifier/rules → abstain when pose quality is poor. UR Fall has only 30 falls and 40 daily-activity sequences and is non-commercial CC BY-NC-SA.
- *Fight:* X3D-XS is merely a temporal backbone. RWF-2000’s 2,000 balanced, trimmed YouTube/CCTV clips do not estimate false alerts in a mostly uneventful stream; commercial data rights are unclear.
- *Fire/smoke:* fine-tune the base detector on audited fixed-camera data, then require persistence/growth and human/sensor confirmation. D-Fire is a useful CC0 image seed, not a live camera-hour test.
- *Weapon:* #link("https://arxiv.org/abs/2303.10703")[CCTV-Gun] reports UCF handguns averaging 16 pixels and cross-dataset AP50 of only 3.7–7.7 in key settings. Measure pixels-on-target before promising anything; tile high-resolution crops and require temporal/human confirmation.

Open-vocabulary models stay off the hot path. The downloaded 694 MB GroundingDINO checkpoint and Florence-2-base are useful for offline annotation or crop verification. Qwen2.5-VL-7B is Apache-2.0, but its smaller 3B sibling is non-commercial—model-family names do not imply one license. #link("https://doi.org/10.1609/aaai.v39i4.32463")[MHBench] documents motion hallucination in VideoLLMs.

= Computer-vision evidence

== Why benchmark scores do not ship

Public VAD datasets—UCF-Crime, ShanghaiTech, Avenue, UCSD Ped2, Street Scene, RWF-2000, NWPU Campus and XD-Violence—made the field possible. They also mix staged events, web/movie footage, few scenes, coarse labels and evaluation distributions unlike a new camera estate. AUROC includes thresholds no operator would tolerate. Prevalence alone does not mathematically inflate AUROC; it changes precision and absolute alarm burden. Correlated positive frames must not be counted as independent notifications.

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
    [#link("https://openaccess.thecvf.com/content/CVPR2026W/AUTOPILOT/html/Picek_ACCIDENT_A_Benchmark_Dataset_for_Vehicle_Accident_Detection_from_Traffic_CVPRW_2026_paper.html")[ACCIDENT]], [2,027 real + 2,211 synthetic accident clips], [Five-way collision type: Qwen 0.115, Molmo 0.271 vs majority 0.335; DINOv2 0.440, cropped SigLIP2 0.471. Oracle accident-frame context; not accident/no-accident detection. VLM spatial localization beats simple priors.],
    [#link("https://openaccess.thecvf.com/content/CVPR2026W/VAND/papers/Khalili_STREAM-OOD_Regime-Aware_Sequential_Monitoring_for_Streaming_Out-of-Distribution_Detection_CVPRW_2026_paper.pdf")[STREAM-OOD]], [1,440 hours / 30 NYC intersections; streaming regime monitoring], [Reports 1.6 false alerts per normal hour, 1.7 on 10 unseen intersections. Private data, controlled shifts, no runnable artifact found; TTD frame/second ambiguity. Useful monitoring evidence, not a threat model.],
    [#link("https://openaccess.thecvf.com/content/WACV2026/html/Qi_SmokeBench_Evaluating_Multimodal_Large_Language_Models_for_Wildfire_Smoke_Detection_WACV_2026_paper.html")[SmokeBench]], [MLLM wildfire smoke recognition/localization], [All tested models struggled on small/early smoke localization; apparent positive accuracy could coexist with bad negative behavior. Use a dedicated temporal model.],
    [CADE / AnyAnomaly / ASK-HINT / VADER], [Continual learning; custom prompts; causal explanations], [Useful experiment lane. AnyAnomaly has no own checkpoint; ASK-HINT has no temporal model; VADER depends on upstream window selection.],
    [Three 2026 arXiv audits], [Cross-dataset and AUC failure analyses], [Convergent warning only: unreviewed. Title-only/unavailable ECCV entries were excluded.],
  )
]

#callout(
  [2026 verdict],
  [The reviewed work does not supply a ready general threat checkpoint. STREAM-OOD does supply held-out-location camera-hour evaluation, so a blanket absence claim would be wrong. Its scene-shift task, private corpus and reported alert burden do not justify deployment for threats. Retain the evaluation methods and test narrow models locally.],
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

Use public data to initialize, never certify. Collect authorized target footage across cameras, day/night/weekend, weather and long uneventful periods; safely stage positives. Hold out sites as well as cameras/dates where possible. Adjacent clips from one source never cross train/test boundaries. Freeze thresholds before the blind test; distinguish staged coverage from natural-event recall.

== Required measures

- Event-level precision, recall and 95% confidence intervals—not only frame mAP/AUC.
- False incidents and delivered nuisance notifications per valid negative camera-hour, by camera/rule and site total; also report camera-days and suppressed candidates.
- Entry-to-qualification, qualification-to-local-notification and evidence-ready p50/p95 latency separately; include dropped-frame/queue age and blind time.
- Stream/inference uptime, dropped frames, compute, memory, thermals and power.
- Performance by camera, light, weather, distance, occlusion and event subtype.
- Operator acknowledgement, disposition time and overrides.

Suggested pilot targets are *product choices, not established capability*: ≥90% recall on predeclared staged zone entries, with counts/confidence intervals; a jointly agreed site-wide interruption budget; p95 local notification within 3 s of rule qualification; ≥99% seven-day pipeline availability; no media egress by default. Persistence time must be added to qualification-to-notification latency. One nuisance alert/day/rule could mean 32/day on eight cameras and four rules, so it is not an acceptable universal budget.

Zero false incidents over 72 valid negative camera-hours gives an approximate one-sided 95% Poisson upper bound of one/day, only under stationary independent-event assumptions. Report camera/day blocks to expose temporal correlation; outage hours do not count as successful negative monitoring. Track-rule accuracy, event precision and operator burden are separate measurements.

== Twelve weeks

#smalltable[
  #table(
    columns: (0.7fr, 1.4fr, 3.5fr),
    inset: 4.5pt,
    stroke: rule,
    fill: (x, y) => if y == 0 { navy } else if calc.rem(y, 2) == 0 { rgb("#F6F9FA") },
    table.header([#text(fill: white, weight: "bold")[Weeks]], [#text(fill: white, weight: "bold")[Work]], [#text(fill: white, weight: "bold")[Exit evidence]]),
    [1–2], [One complete slice], [Reviewed fork, one camera, supported detector, zone incident, local playable evidence and operator verdict; liveness and security checks.],
    [3–4], [Camera/data campaign], [Measure hardware/codec capacity and target-domain misses; collect long negatives. Compare RTMDet export only if needed.],
    [5–6], [Rules + operations], [Add one justified trajectory/schedule rule; validate retention, disk full, reconnect, timestamps and reboot.],
    [7–8], [Optional experiment], [One specialist or 2026 shadow model only if artifacts, rights and time permit; core reliability takes priority.],
    [9–10], [Data campaign], [Long negatives + safely staged positives across conditions; camera/date-separated frozen split.],
    [11–12], [Blind pilot + thesis], [Event metrics, camera-day burden, latency, uptime, hardware cost and failure taxonomy—including failures in the demo.],
  )
]

= Startup boundary, privacy and research quality

== Commercial thesis

The wedge is reliable retrofit for one vertical—warehouses, campuses or small multi-site operators—not a generic surveillance platform. Sell fewer unattended cameras and less manual review. The moat is tested device adapters, target-domain data, calibration, alert-quality operations, human feedback, failure observability and trusted rollout; public detector weights are not a moat.

Exclude face and emotion recognition. Jordan’s Personal Data Protection Law No. 24 of 2023 has been effective since 17 March 2024 and treats biometric data as sensitive (#link("https://www.modee.gov.jo/EN/Pages/FAQs")[Ministry FAQ]). European guidance demands a specific purpose, necessity and minimization; ordinary video becomes biometric processing when technically used for unique identification (#link("https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices_en_0.pdf")[EDPB guidance]). Determine controller/processor roles, signage, retention, access, export, deletion and incident response with local counsel.

Minimize viewing area, audio and retention before collection; no cross-camera identity tracking. Pseudonymous track IDs, poses, thumbnails and metadata can remain personal data. A motion mask does not redact stored video. Privacy redaction requires a separately tested media transformation, often re-encoding. Enforce authorization and deletion across local clips, temporary buffers, optional hosted copies and backups; cloud metadata-only operation still needs a defined purpose and field allowlist.

== Paper discovery and quality screen

The inherited discovery log records CVF CVPR/WACV 2026 title scans, scholarly indexes, arXiv and citation chasing. This independent pass checked primary source and release code, reread decisive full papers, and searched surveillance/streaming work through 5 September 2026. It added STREAM-OOD and its supplement. Search completeness is bounded by accessible sources; unavailable papers and title-only matches support no technical conclusion. See the audit for access gaps and exact pins.

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
  [Implementation decision],
  [Keep Frigate's useful whole and own the product seams. Start with its supported detector and inherited tracking; compare RTMDet/ByteTrack only against target evidence. MediaMTX/DL Streamer are contingent replacements, not a mandatory second stack. No CCTV code or new dependencies are part of this review.],
)

#pagebreak()
= First complete capability to implement

*One local, reviewable person-in-zone incident.* Input: one authorized H.264 RTSP camera (main/substream if available), supplied credentials, one polygon and one supported Intel Linux PC. Reuse Frigate's OpenVINO SSD detector, Norfair, zone evaluator, recording/index and local UI. Initially one operator, one person rule, no cloud or specialist.

Define qualifying presence as a valid person's bottom-center remaining in the zone for two seconds, with a documented brief tracking-gap grace. Add a small incident module: stable ID and camera epoch, policy version, one open incident per track/zone, explicit end/reset semantics and local acknowledgement plus true/false/uncertain verdict. Preserve five seconds before and ten seconds after qualification as a bounded evidence clip; re-entry after the reset policy can create a new incident. The alert can appear while evidence is still pending. Never invent pre-roll at startup or media during an outage.

Prove it with timestamped replay and authorized live footage: at least 20 declared positive traversals plus short/boundary/occluded negatives, 72 valid negative camera-hours at frozen settings, a declared ≥90% staged-recall target and confidence intervals. Measure p95 UI delivery ≤3 s after qualification and evidence readiness separately. Check one incident per qualifying continuous track, clip timestamps, persisted verdict after restart, no secret in URLs/logs, and authenticated evidence access. Unplug the camera, interrupt decode, restart the edge, fill its evidence quota and disconnect WAN; health/evidence states must remain honest and the NVR must keep recording when its own dependencies are intact.

This slice tests the foundation, CV and operator path together. It does not certify the alarm rate from 20 staged events or generalize one camera to a site. If the supported baseline misses obvious people, measure/resolve that before adding rule types. Approval is required before creating this implementation.

*My next move would be to implement the single-camera, locally reviewable person-in-zone incident capability in a controlled Frigate fork, including decoded-frame health, playable evidence and a persistent operator verdict.*

#v(4mm)
#text(size: 7.5pt, fill: rgb("#607481"))[
  Evidence catalog: authoritative links, review status and adoption decisions are maintained in the repository README. Bulk clones, papers, model checkpoints and rendered artifacts were intentionally excluded from version control.
]
