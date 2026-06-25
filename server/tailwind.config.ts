import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        trustBlue: "#185FA5",
        skyBlue: "#B5D4F4",
        coral: "#D85A30",
        teal: "#1D9E75",
        amber: "#EF9F27",
        charcoal: "#2C2C2A",
        warmSand: "#F1EFE8",
      },
      fontFamily: {
        poppins: ["var(--font-poppins)", "sans-serif"],
        inter: ["var(--font-inter)", "sans-serif"],
      },
    },
  },
  plugins: [],
};
export default config;
