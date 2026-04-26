import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  basePath: "/caocap",
  async redirects() {
    return [
      {
        source: "/",
        destination: "/caocap",
        basePath: false,
        permanent: false, // Temporary redirect for now
      },
    ];
  },
};

export default nextConfig;
