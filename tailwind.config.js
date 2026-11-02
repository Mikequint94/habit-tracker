/** @type {import('tailwindcss').Config} */
// Tailwind scans index.html (markup + the class strings inside the <script>).
// After adding/changing classes, rebuild with: npm run build:css
module.exports = {
  content: ['./index.html'],
  theme: { extend: {} },
  plugins: [],
};
