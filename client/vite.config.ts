// vite.config.{ts,js}
import gleam from "vite-gleam";
import tailwindcss from "tailwindcss"


export default {
  plugins: [gleam()],
  css: {
    postcss: {
      plugins: [tailwindcss],
    },
  }
};