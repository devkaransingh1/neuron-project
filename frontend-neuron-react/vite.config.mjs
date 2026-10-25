import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";

const rootDir = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": rootDir,
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "https://miniproject-neuron.onrender.com/",
        changeOrigin: true,
      },
    },
  },
});
