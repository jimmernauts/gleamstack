import { main } from './src/app.gleam'
import 'virtual:uno.css'

document.addEventListener("DOMContentLoaded", () => {
    console.log("DOMContentLoaded")
  const dispatch = main();
});