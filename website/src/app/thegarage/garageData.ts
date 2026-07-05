export type GarageTimelineItem = {
  date: string;
  title: string;
  detail: string;
};

export type GaragePillar = {
  title: string;
  detail: string;
};

export type GarageStat = {
  label: string;
  value: string;
};

export type GarageAcceleratorData = {
  name: string;
  eyebrow: string;
  tagline: string;
  overview: string;
  status: "draft" | "coming-soon" | "applications-open" | "in-session" | "closed";
  statusLabel: string;
  cohortLabel: string;
  audience: string;
  applicationUrl: string | null;
  applicationCta: string;
  contactEmail: string;
  pillars: GaragePillar[];
  timeline: GarageTimelineItem[];
  stats: GarageStat[];
};

/** Edit this file to publish Accelerator updates on /caocap/thegarage. */
export const garageAccelerator: GarageAcceleratorData = {
  name: "The Garage",
  eyebrow: "CAOCAP Accelerator",
  tagline: "A builder studio for creative people learning software by making real apps.",
  overview:
    "The Garage is where CAOCAP cohorts ship Mini-Apps, learn in public, and grow with mentorship from the product team. Program details, dates, and application links will be published here.",
  status: "draft",
  statusLabel: "Details coming soon",
  cohortLabel: "Cohort 01",
  audience:
    "Creative builders — designers, founders, students, and product thinkers — who want to learn software by building, not by outsourcing it to a black-box generator.",
  applicationUrl: null,
  applicationCta: "Apply to The Garage",
  contactEmail: "azzam.rar@gmail.com",
  pillars: [
    {
      title: "Build on the canvas",
      detail:
        "Work inside CAOCAP's spatial studio with live previews, SRS notes, and human-reviewed AI edits from CoCaptain."
    },
    {
      title: "Learn with mentorship",
      detail:
        "Get guidance on product thinking, software structure, and shipping — focused on capability, not dependency on AI."
    },
    {
      title: "Ship real Mini-Apps",
      detail:
        "Leave the program with working projects, a clearer mental model of software, and a portfolio you can show."
    }
  ],
  timeline: [
    {
      date: "TBD",
      title: "Applications open",
      detail: "Founders and builders can apply for the first Garage cohort."
    },
    {
      date: "TBD",
      title: "Cohort kickoff",
      detail: "Selected builders start their CAOCAP projects with onboarding and studio sessions."
    },
    {
      date: "TBD",
      title: "Demo day",
      detail: "Cohort presents Mini-Apps built during the accelerator."
    }
  ],
  stats: [
    { label: "Format", value: "Remote + CAOCAP" },
    { label: "Focus", value: "Learn by building" },
    { label: "Cohort", value: "Cohort 01" }
  ]
};
