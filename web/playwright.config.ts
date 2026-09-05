import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  workers: 1,
  use: { baseURL: "http://127.0.0.1:8011", screenshot: "only-on-failure" },
  webServer: {
    command: "../.venv/bin/python ../tests/e2e_server.py",
    url: "http://127.0.0.1:8011/api/health",
    reuseExistingServer: false,
    timeout: 20000,
  },
});
