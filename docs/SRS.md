# CAOCAP Software Requirements Specification

| Field | Value |
| --- | --- |
| Document version | 0.1 Draft |
| Product | CAOCAP |
| Status | Living vision-level requirements baseline |
| Owner | CAOCAP project |
| Last updated | 2026-09-04 |
| Reference model | ISO/IEC/IEEE 29148:2018 |

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.1 Draft | 2026-09-04 | Initial vision-level requirements baseline |

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) defines the intended capabilities and quality requirements of CAOCAP. It describes the envisioned complete product rather than the functionality currently implemented in the repository.

This is a living specification aligned with the requirements-engineering guidance in ISO/IEC/IEEE 29148:2018. It does not claim formal conformity or certification.

### 1.2 Scope

CAOCAP is an AI-supported learning product for complete beginners exploring digital skills. It helps a learner sample representative work, choose a direction, build skills through practical projects, collect evidence of progress, prepare portfolio material, and understand how those skills may apply to paid opportunities.

The system includes the learner experience, AI mentor behavior, learning and project content, progress records, portfolio preparation, and the services needed to make those capabilities available across supported clients.

### 1.3 Intended audience

This document is intended for product owners, designers, engineers, content authors, quality-assurance contributors, security and privacy reviewers, and future project contributors.

### 1.4 References

- [ISO/IEC/IEEE 29148:2018 — Requirements engineering](https://www.iso.org/standard/72089.html)
- [CAOCAP product vision](product-vision.md)
- [CAOCAP repository README](../README.md)

### 1.5 Requirement conventions

Normative requirements use **shall** and have a stable identifier:

- `CAO-FR-nnn`: functional requirement
- `CAO-IR-nnn`: external-interface requirement
- `CAO-DR-nnn`: data requirement
- `CAO-NFR-nnn`: quality or non-functional requirement
- `CAO-CON-nnn`: constraint

Priorities express product importance rather than delivery order:

- **High:** essential to the product's purpose, safety, or trustworthiness
- **Medium:** important to a complete experience but can follow the essential flow
- **Low:** desirable enhancement

Verification methods are **Test**, **Demonstration**, **Inspection**, or **Analysis**. Requirements affected by an unresolved product decision reference a numbered item in [Open issues](#8-open-issues).

## 2. Overall description

### 2.1 Product context

CAOCAP is conceived as a multi-client product backed by shared learning, mentorship, progress, and account capabilities. The repository currently contains only basic iOS and macOS SwiftUI starter applications plus placeholder directories for other clients. Current implementation status does not limit the product requirements in this document.

The product supports a learner's decisions and practice. It is not an employer, income-guarantee service, accredited education provider, or substitute for qualified human advice.

### 2.2 Product goals

| ID | Goal |
| --- | --- |
| `PG-01` | Help beginners make an informed choice among digital-skill directions. |
| `PG-02` | Help learners develop practical capability through guided work. |
| `PG-03` | Provide useful, transparent guidance and feedback while preserving learner agency. |
| `PG-04` | Help learners recognize, retain, and present evidence of progress. |
| `PG-05` | Help learners prepare to pursue realistic paid opportunities without promising outcomes. |

### 2.3 Stakeholders and user classes

| User class | Description | Primary needs |
| --- | --- | --- |
| Learner | A person exploring or developing a digital skill, initially with little or no prior experience | Clear choices, safe guidance, practice, feedback, progress, and evidence |
| Content maintainer | A person responsible for skill descriptions, tasks, projects, criteria, and learning paths | Controlled content creation, revision, and publication |
| Product operator | A person responsible for service health, policy enforcement, and user support | Operational visibility, configuration, and incident handling |
| Reviewer | A future role that may provide human review or moderation | Role boundaries and workflow remain unresolved in `TBD-017` |

### 2.4 Operating environment

The envisioned system may be delivered through native and web clients. Supported platforms, minimum versions, release order, offline behavior, and shared-service architecture remain open decisions. See `TBD-014` and `TBD-020`.

### 2.5 Assumptions and dependencies

- Learners have access to a supported device and, unless offline support is later defined, an internet connection.
- AI mentor functions depend on one or more external or self-hosted model services; the provider and routing strategy remain unresolved in `TBD-005`.
- Some learning activities may depend on external tools used to practise a chosen skill.
- Legal, privacy, age, language, regional, and accessibility targets require decisions recorded in the open-issues register.

### 2.6 Exclusions

The vision baseline does not include:

- guaranteed employment, clients, earnings, or learning outcomes;
- automatic submission of applications, proposals, or financial transactions;
- an open marketplace connecting learners directly with buyers;
- formal accreditation or professional certification; or
- final architecture, vendor, monetization, or platform-release commitments.

Changes to these boundaries require product review and a revision to this SRS.

## 3. System capabilities and user journeys

### 3.1 Capability groups

| Capability | Description |
| --- | --- |
| Skill exploration | Explain digital skills and let learners try representative work |
| Direction selection | Help learners compare experiences and choose or revise a path |
| Guided development | Organize tasks and projects into understandable learning progressions |
| AI mentorship | Provide contextual help and criteria-based feedback with transparent limits |
| Progress and evidence | Preserve attempts, feedback, achievements, and demonstrated capabilities |
| Portfolio preparation | Help learners select and present suitable completed work |
| Opportunity preparation | Help learners translate capabilities into realistic service and work contexts |
| Content operations | Let authorized maintainers govern the learning material behind the experience |

### 3.2 Major user journeys

| ID | Journey | Successful outcome |
| --- | --- | --- |
| `UJ-01` | Explore skills | The learner understands and samples more than one possible direction. |
| `UJ-02` | Choose a direction | The learner makes an informed, revisable choice using recorded experience. |
| `UJ-03` | Build capability | The learner completes guided work and receives actionable feedback. |
| `UJ-04` | Demonstrate progress | The learner identifies completed work and evidence suitable for presentation. |
| `UJ-05` | Prepare for opportunities | The learner can describe a capability and identify realistic next actions. |

## 4. Functional requirements

### 4.1 Learner profile and continuity

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-001` | The system shall provide each learner with a persistent workspace for choices, activity, progress, feedback, and portfolio candidates. | Enables a journey across sessions. | High | `PG-01`–`PG-04` | Test |
| `CAO-FR-002` | The system shall allow a learner to resume the most recent incomplete activity from its last persisted state. | Reduces loss and rework. | High | `UJ-01`–`UJ-04` | Test |
| `CAO-FR-003` | The system shall allow a learner to record and revise goals, interests, constraints, and experience relevant to choosing a direction. | Keeps guidance grounded in learner context. | High | `PG-01` | Demonstration |
| `CAO-FR-004` | The system shall distinguish learner-owned profile information from system-inferred observations. | Prevents inference from appearing as user-provided fact. | High | Product principle: transparency | Inspection, Test |

### 4.2 Skill exploration

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-010` | The system shall present a browsable set of digital-skill directions available for exploration. | Gives learners concrete options. | High | `PG-01`, `UJ-01` | Demonstration |
| `CAO-FR-011` | The system shall describe each skill direction in beginner-accessible terms, including representative activities, outputs, prerequisites, and opportunity contexts. | Supports informed exploration. | High | `PG-01` | Inspection |
| `CAO-FR-012` | The system shall provide at least one representative guided task for every published skill direction. | Enables experience before commitment. | High | `UJ-01` | Test |
| `CAO-FR-013` | The system shall state the objective, expected output, estimated effort, required tools, and completion criteria before a learner begins an exploration task. | Makes tasks understandable and comparable. | High | `UJ-01` | Inspection |
| `CAO-FR-014` | The system shall let a learner record a reflection after an exploration task. | Captures evidence for direction selection. | Medium | `PG-01` | Demonstration |
| `CAO-FR-015` | The system shall let a learner compare explored directions using task history, reflections, stated interests, and relevant constraints. | Grounds choice in recorded experience. | High | `UJ-02` | Demonstration |

### 4.3 Direction selection and learning path

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-020` | The system shall allow a learner to select a skill direction without presenting the choice as permanent. | Preserves learner agency. | High | `PG-01`, `UJ-02` | Demonstration |
| `CAO-FR-021` | The system shall explain the learner-provided and system-observed factors used in any direction recommendation. | Makes recommendations transparent. | High | `PG-03` | Test |
| `CAO-FR-022` | The system shall allow a learner to reject a recommendation and choose a different available direction. | Keeps the decision with the learner. | High | Product principle: agency | Test |
| `CAO-FR-023` | The system shall allow a learner to revise a selected direction while retaining prior progress records. | Treats redirection as learning. | High | `PG-01`, `PG-04` | Test |
| `CAO-FR-024` | The system shall present an ordered learning path for a selected direction, including its intended outcomes and completion criteria. | Turns a choice into actionable work. | High | `PG-02` | Demonstration |

### 4.4 Guided tasks and projects

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-030` | The system shall present each guided activity with an objective, instructions, expected output, required resources, and evaluation criteria. | Provides a consistent practice contract. | High | `PG-02` | Inspection |
| `CAO-FR-031` | The system shall accept the learner's work or a record of externally completed work in the formats enabled for that activity. | Captures evidence of practice. | High | `UJ-03` | Test |
| `CAO-FR-032` | The system shall preserve distinct learner attempts and associate feedback with the attempt it evaluates. | Makes iteration observable. | High | `PG-02`, `PG-04` | Test |
| `CAO-FR-033` | The system shall allow a learner to revise and resubmit work when the activity permits iteration. | Supports improvement from feedback. | High | `UJ-03` | Test |
| `CAO-FR-034` | The system shall distinguish short practice tasks from portfolio-eligible projects. | Sets appropriate expectations for outputs. | Medium | `PG-04` | Inspection |
| `CAO-FR-035` | The system shall communicate dependencies or prerequisites before a learner starts an activity. | Prevents avoidable dead ends. | Medium | `PG-02` | Test |

### 4.5 AI mentorship and feedback

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-040` | The system shall provide AI mentor assistance in the context of the learner's active direction, activity, and permitted progress data. | Makes help relevant. | High | `PG-03` | Test |
| `CAO-FR-041` | The system shall identify AI-generated guidance and feedback as AI-generated. | Supports informed trust. | High | Product principle: transparency | Inspection, Test |
| `CAO-FR-042` | The system shall map evaluative feedback to the activity's published criteria. | Makes feedback actionable and auditable. | High | `PG-02`, `PG-03` | Test |
| `CAO-FR-043` | The system shall separate observed evidence in submitted work from suggestions and uncertain inferences. | Reduces misleading certainty. | High | `PG-03` | Analysis, Test |
| `CAO-FR-044` | The system shall let a learner request clarification or a different explanation of mentor guidance. | Serves beginners with varied understanding. | High | Product principle: beginner clarity | Demonstration |
| `CAO-FR-045` | The system shall prevent AI mentor output from silently changing learner work, direction choices, progress, or portfolio content. | Preserves ownership and control. | High | Product principle: agency | Test |
| `CAO-FR-046` | The system shall provide a way for learners to report unsafe, inappropriate, or materially incorrect mentor output. | Enables safety feedback and response. | High | Product principle: trust | Demonstration |
| `CAO-FR-047` | The system shall communicate when mentor feedback cannot be produced or is materially limited by missing context or service failure. | Avoids fabricated completion or certainty. | High | `PG-03` | Test |

### 4.6 Progress and evidence

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-050` | The system shall show progress in terms of activities, attempts, feedback, and demonstrated outcomes. | Emphasizes evidence over completion marks. | High | `PG-04` | Demonstration |
| `CAO-FR-051` | The system shall distinguish completion from demonstrated proficiency. | Prevents overstated capability. | High | Product principle: practice produces evidence | Test |
| `CAO-FR-052` | The system shall let a learner inspect the evidence supporting any system-presented proficiency assessment. | Makes assessment explainable. | High | `PG-03`, `PG-04` | Demonstration |
| `CAO-FR-053` | The system shall preserve progress from previously selected directions and label its originating direction. | Supports exploration and redirection. | Medium | `PG-01`, `PG-04` | Test |

### 4.7 Portfolio preparation

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-060` | The system shall allow a learner to select eligible completed projects as portfolio candidates. | Keeps publication decisions with the learner. | High | `PG-04`, `UJ-04` | Demonstration |
| `CAO-FR-061` | The system shall allow a learner to add context describing the goal, process, contribution, tools, and outcome of a portfolio candidate. | Helps evidence communicate capability. | High | `PG-04` | Test |
| `CAO-FR-062` | The system shall allow a learner to review and edit AI-assisted portfolio text before it is saved as learner-approved content. | Preserves authorship and accuracy. | High | Product principle: agency | Test |
| `CAO-FR-063` | The system shall exclude private learning records from portfolio output unless the learner explicitly selects them for inclusion. | Protects learner privacy. | High | Product principle: trust | Test |
| `CAO-FR-064` | The system shall preview the content included in any portfolio output before the learner shares or exports it. | Prevents accidental disclosure. | High | `PG-04` | Demonstration |

### 4.8 Paid-opportunity preparation

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-070` | The system shall explain example paid-work contexts associated with a skill without representing them as guaranteed opportunities. | Connects learning to realistic uses. | High | `PG-05`, `UJ-05` | Inspection |
| `CAO-FR-071` | The system shall help a learner map demonstrated capabilities and portfolio evidence to a potential service or role description. | Makes acquired capability communicable. | High | `PG-05` | Demonstration |
| `CAO-FR-072` | The system shall distinguish verified learner activity from learner claims and AI-generated suggestions in opportunity-preparation material. | Reduces misrepresentation. | High | `PG-03`, `PG-05` | Test |
| `CAO-FR-073` | The system shall allow a learner to review and edit all AI-assisted opportunity-preparation material before export or use. | Keeps external representation under learner control. | High | Product principle: agency | Test |
| `CAO-FR-074` | The system shall present relevant readiness gaps and suggested next actions when available evidence does not support a target service or role. | Encourages realistic preparation. | Medium | `PG-05` | Demonstration |

### 4.9 Content operations

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-FR-080` | The system shall allow authorized content maintainers to create, revise, preview, publish, and retire skill directions, paths, activities, projects, and evaluation criteria. | Keeps learning content governable. | High | Operational necessity | Demonstration |
| `CAO-FR-081` | The system shall version published learning content used by a learner attempt. | Preserves the basis for historical feedback and evidence. | High | `PG-03`, `PG-04` | Test |
| `CAO-FR-082` | The system shall prevent unpublished content revisions from altering the recorded context of completed learner attempts. | Protects historical integrity. | High | Operational necessity | Test |
| `CAO-FR-083` | The system shall restrict content-management functions to authorized roles. | Prevents unauthorized publication. | High | Security | Test |

## 5. External-interface and data requirements

### 5.1 External interfaces

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-IR-001` | Supported clients shall expose the same meaning for learner progress, activity state, mentor feedback, and portfolio eligibility. | Prevents client-specific interpretation of core records. | High | Multi-client vision | Analysis, Test |
| `CAO-IR-002` | A supported client shall communicate whether an action requires network access before an offline learner loses unsaved work. | Makes connectivity constraints visible. | Medium | User continuity | Test |
| `CAO-IR-003` | The AI-service interface shall send only the learner and activity context authorized for the requested mentor function. | Limits unnecessary disclosure. | High | Privacy | Inspection, Test |
| `CAO-IR-004` | The AI-service interface shall return a distinguishable failure state when usable mentor output is unavailable. | Supports honest failure handling. | High | `CAO-FR-047` | Test |
| `CAO-IR-005` | The persistence interface shall support idempotent saving of learner work and progress where repeated requests may occur. | Prevents duplicate or inconsistent records. | High | Reliability | Test |
| `CAO-IR-006` | The identity interface shall enforce the authentication and session policy selected in `TBD-004`. | Connects implementation to the future identity decision. | High | Security | Test |
| `CAO-IR-007` | Export or sharing interfaces shall disclose the exact portfolio or opportunity-preparation content transferred outside CAOCAP. | Preserves informed control. | High | Product principle: transparency | Demonstration |
| `CAO-IR-008` | A supported client shall make the learner's current journey stage, active activity state, and available next action visible. | Keeps navigation understandable for beginners. | High | Product principle: beginner clarity | Demonstration |
| `CAO-IR-009` | A supported client shall request confirmation before an action that irreversibly deletes learner work, progress, or portfolio content. | Prevents accidental loss. | High | Learner control | Test |

### 5.2 Data requirements

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-DR-001` | The system shall maintain logical relationships among a learner, profile, selected directions, activities, attempts, submissions, feedback, progress evidence, and portfolio candidates. | Supports coherent history and traceability. | High | `PG-01`–`PG-04` | Analysis, Test |
| `CAO-DR-002` | The system shall associate every feedback record and proficiency assessment with the content version and learner evidence on which it was based. | Makes evaluation auditable. | High | `PG-03`, `PG-04` | Test |
| `CAO-DR-003` | The system shall record whether material is learner-authored, AI-generated, system-observed, or maintainer-authored when provenance affects interpretation. | Protects authorship and transparency. | High | Product principle: trust | Test |
| `CAO-DR-004` | The system shall allow a learner to obtain a human-readable copy of learner-provided data and retained work, subject to the export scope in `TBD-006`. | Supports access and portability. | High | Privacy | Test |
| `CAO-DR-005` | The system shall allow a learner to request deletion of the learner's account and associated personal data under the retention and legal rules selected in `TBD-006` and `TBD-018`. | Supports learner control and privacy obligations. | High | Privacy | Test |
| `CAO-DR-006` | The system shall prevent one learner from accessing another learner's private profile, work, progress, feedback, or portfolio drafts. | Enforces data isolation. | High | Security | Test |
| `CAO-DR-007` | The system shall retain the minimum data necessary for defined product, safety, legal, and operational purposes. | Limits privacy exposure. | High | Privacy | Inspection, Analysis |
| `CAO-DR-008` | The system shall record learner consent or another approved legal basis before processing personal data for optional purposes. | Separates required and optional processing. | High | Privacy | Test |

## 6. Quality requirements and constraints

### 6.1 Quality requirements

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-NFR-001` | The system shall encrypt authenticated network communication using an approved, currently supported transport-security configuration. | Protects data in transit. | High | Security | Inspection, Test |
| `CAO-NFR-002` | The system shall encrypt stored authentication secrets and sensitive personal data using the controls selected during security design. | Protects retained sensitive data. | High | Security | Inspection, Test |
| `CAO-NFR-003` | The system shall apply least-privilege authorization to learner, maintainer, operator, and reviewer functions. | Limits unauthorized actions. | High | Security | Analysis, Test |
| `CAO-NFR-004` | The system shall avoid placing secrets, authentication tokens, or unnecessary personal data in application logs. | Reduces operational disclosure. | High | Security, Privacy | Inspection, Test |
| `CAO-NFR-005` | The system shall provide notice before learner content or personal data is sent to an external AI service. | Enables informed use of AI processing. | High | Product principle: transparency | Demonstration |
| `CAO-NFR-006` | The system shall support the accessibility conformance target selected in `TBD-009` across every supported client. | Makes the beginner experience inclusive. | High | Product principle: beginner clarity | Inspection, Test |
| `CAO-NFR-007` | The system shall present essential learner instructions and feedback without requiring unexplained specialist terminology. | Serves complete beginners. | High | Product principle: beginner clarity | Inspection, Test |
| `CAO-NFR-008` | The system shall meet the interactive-response targets selected in `TBD-007` under the defined reference workload. | Establishes measurable responsiveness. | Medium | Usability | Test |
| `CAO-NFR-009` | The system shall meet the availability, recovery-point, and recovery-time targets selected in `TBD-008`. | Establishes measurable service continuity. | High | Reliability | Analysis, Test |
| `CAO-NFR-010` | The system shall preserve acknowledged learner work across a single recoverable service or client failure. | Prevents loss of learning evidence. | High | Reliability | Test |
| `CAO-NFR-011` | The system shall provide a safe retry path after a recoverable save, submission, export, or mentor-service failure. | Lets learners continue without duplication. | High | Reliability | Test |
| `CAO-NFR-012` | The system shall apply the AI safety and escalation policy selected in `TBD-010` to mentor input and output. | Creates a verifiable safety boundary. | High | Safety | Analysis, Test |
| `CAO-NFR-013` | The system shall avoid presenting AI-generated evaluation as a professional credential or guaranteed measure of employability. | Prevents misleading claims. | High | Product principle: preparation without promises | Inspection, Test |
| `CAO-NFR-014` | The system shall isolate platform-specific presentation from the meaning and lifecycle of shared learning records. | Supports consistent multi-client behavior. | Medium | Portability, maintainability | Analysis |
| `CAO-NFR-015` | The system shall maintain automated tests that trace to every implemented high-priority requirement. | Preserves requirement-to-verification continuity. | High | Requirements governance | Inspection |
| `CAO-NFR-016` | The system shall expose service failures with enough non-sensitive context for operators to diagnose the affected capability and request. | Supports maintainability without leaking learner data. | Medium | Operability | Inspection, Demonstration |

### 6.2 Constraints

| ID | Requirement | Rationale | Priority | Source | Verification |
| --- | --- | --- | --- | --- | --- |
| `CAO-CON-001` | CAOCAP shall not guarantee employment, clients, revenue, or a specific learning outcome. | Maintains honest product positioning. | High | `PG-05` | Inspection |
| `CAO-CON-002` | CAOCAP shall keep the learner in control of direction selection, submission, portfolio publication, and external opportunity material. | Preserves learner agency. | High | Product principles | Demonstration, Test |
| `CAO-CON-003` | CAOCAP shall distinguish implemented capabilities from planned capabilities in user-facing and repository documentation. | Prevents misleading claims. | High | Project governance | Inspection |
| `CAO-CON-004` | CAOCAP shall support replacing an AI model or provider without redefining learner progress, evidence, or content records. | Avoids binding the product model to one AI vendor. | Medium | Maintainability | Analysis |
| `CAO-CON-005` | CAOCAP shall require learner approval before AI-assisted content is represented externally as the learner's own statement or work description. | Protects authorship and accuracy. | High | Product principle: agency | Test |

## 7. Verification, acceptance, and traceability

### 7.1 Acceptance approach

A requirement becomes eligible for release acceptance when:

1. its referenced open issues are resolved for the release;
2. its implementation scope and acceptance evidence are identified;
3. the stated verification method has been completed;
4. failures and accepted deviations are recorded; and
5. the requirement-to-test relationship is retained with the release record.

This vision baseline does not define the first release boundary. Release planning selects a coherent subset of requirements and must preserve any safety, privacy, or integrity requirements that apply to the selected capabilities.

### 7.2 Goal and journey traceability

| Goal | Journeys | Primary requirements |
| --- | --- | --- |
| `PG-01` Informed direction | `UJ-01`, `UJ-02` | `CAO-FR-003`–`004`, `CAO-FR-010`–`024`, `CAO-FR-053` |
| `PG-02` Practical capability | `UJ-03` | `CAO-FR-024`, `CAO-FR-030`–`035`, `CAO-FR-042`, `CAO-FR-050`–`052` |
| `PG-03` Transparent guidance | `UJ-02`, `UJ-03` | `CAO-FR-021`–`022`, `CAO-FR-040`–`047`, `CAO-FR-052`, `CAO-DR-002`–`003` |
| `PG-04` Evidence and portfolio | `UJ-03`, `UJ-04` | `CAO-FR-032`–`034`, `CAO-FR-050`–`064`, `CAO-DR-001`–`003` |
| `PG-05` Opportunity preparation | `UJ-05` | `CAO-FR-070`–`074`, `CAO-CON-001`, `CAO-CON-005` |

Cross-cutting interface, data, quality, and constraint requirements apply wherever their referenced concern is present.

## 8. Open issues

An open issue marks a decision that is intentionally not invented in this vision baseline. Resolving an item requires updating affected requirements and the revision history.

| ID | Decision needed | Affected areas |
| --- | --- | --- |
| `TBD-001` | Define the initial skill taxonomy, catalog, and publication criteria. | Exploration, content operations |
| `TBD-002` | Define minimum learner age, guardian-consent rules, and age-appropriate experiences. | Identity, privacy, safety, content |
| `TBD-003` | Select initial languages, regions, and localization policy. | Content, interfaces, support |
| `TBD-004` | Select identity, authentication, account-recovery, and session policies. | `CAO-IR-006`, security |
| `TBD-005` | Select AI providers or models, routing, context limits, evaluation, and fallback behavior. | AI mentorship, privacy, reliability |
| `TBD-006` | Define data classification, retention periods, export scope, deletion timing, backups, and residency. | `CAO-DR-004`–`008`, security, privacy |
| `TBD-007` | Set measurable response-time and AI-feedback latency targets and reference workloads. | `CAO-NFR-008` |
| `TBD-008` | Set availability, recovery-point, recovery-time, and backup-restoration targets. | `CAO-NFR-009`–`011` |
| `TBD-009` | Select accessibility standards, conformance level, and platform-specific acceptance methods. | `CAO-NFR-006`, all clients |
| `TBD-010` | Define AI safety categories, moderation thresholds, escalation paths, appeals, and incident response. | `CAO-FR-046`, `CAO-NFR-012` |
| `TBD-011` | Define portfolio publication, export formats, hosting, visibility, and revocation behavior. | `CAO-FR-060`–`064`, `CAO-IR-007` |
| `TBD-012` | Decide whether opportunity data or third-party opportunity integrations are in scope. | `CAO-FR-070`–`074`, external interfaces |
| `TBD-013` | Select submission formats, file limits, malware controls, and external-tool evidence rules. | `CAO-FR-031`–`033`, security |
| `TBD-014` | Select supported clients, minimum platform versions, and release order. | Operating environment, portability |
| `TBD-015` | Define the business model, entitlements, subscriptions, and payment boundaries. | Access control, future billing |
| `TBD-016` | Define analytics, telemetry, consent, minimization, and product-measurement policy. | Privacy, operations |
| `TBD-017` | Define evaluation rubrics, proficiency semantics, human-review roles, and dispute handling. | Feedback, progress, reviewer role |
| `TBD-018` | Identify governing legal jurisdictions and approve privacy terms, user terms, and compliance obligations. | Privacy, safety, data lifecycle |
| `TBD-019` | Define notification channels, learner controls, frequency, and quiet-time behavior. | Engagement, external interfaces |
| `TBD-020` | Define offline capabilities and synchronization-conflict behavior. | Operating environment, `CAO-IR-002` |

## 9. Document governance

Changes to product goals, requirements, constraints, or open-issue resolutions are recorded in the revision history. Requirement identifiers are not reused after removal; removed requirements remain discoverable through version history. Implementation plans and release specifications may narrow this vision baseline but must identify the requirement IDs they include, defer, or supersede.
