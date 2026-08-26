import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  async redirects() {
    return [
      {
        source: '/catalog',
        destination: '/data-hub',
        permanent: true,
      }
    ]
  },
};
export default nextConfig;
