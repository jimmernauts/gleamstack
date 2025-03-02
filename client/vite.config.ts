// vite.config.{ts,js}
import gleam from "vite-gleam";
import tailwindcss from "@tailwindcss/vite"


export default {
  plugins: [gleam(),tailwindcss()],
  test: {
    diff: {
      truncateThreshold: 10,
      expand:false
    }
  },
};