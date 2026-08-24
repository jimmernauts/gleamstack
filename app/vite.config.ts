import { defineConfig } from "vite";
import gleam from "vite-gleam";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs";
import path from "node:path";
import type { IncomingMessage, ServerResponse } from "node:http";

export default defineConfig({
	plugins: [
		gleam() as any,
		tailwindcss(),
		{
			name: "serve-dev-manifest",
			configureServer(server) {
				server.middlewares.use(
					"/manifest.json",
					(req: IncomingMessage, res: ServerResponse, next: () => void) => {
						const manifestPath = path.resolve(
							process.cwd(),
							"public/manifest.dev.json",
						);
						try {
							const content = fs.readFileSync(manifestPath, "utf-8");
							res.setHeader("Content-Type", "application/json");
							res.end(content);
						} catch (e) {
							next();
						}
					},
				);
			},
		},
	],
	build: {
		target: "esnext",
		rollupOptions: {
			input: {
				main: path.resolve(__dirname, "index.html"),
				"spike-assets/turso-client": path.resolve(__dirname, "src/spike/turso-client.ts"),
			},
			output: {
				entryFileNames: (chunkInfo) => {
					if (chunkInfo.name === "spike-assets/turso-client") return "spike-assets/turso-client.js";
					return "assets/[name]-[hash].js";
				},
			},
		},
	},
});
