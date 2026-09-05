import { expect, test } from "@playwright/test";

const accessKey = "browser-test-access-key-00000000000000";

test("unlock, validate, save, probe, reload, and remove a camera", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByLabel("Local access key").fill("incorrect");
  await page.getByRole("button", { name: "Unlock workspace" }).click();
  await expect(page.getByRole("alert")).toContainText("local access key");
  await page.getByLabel("Local access key").fill(accessKey);
  await page.getByRole("button", { name: "Unlock workspace" }).click();
  await expect(page.getByText("A clearer view starts here")).toBeVisible();
  await page.getByRole("button", { name: "Add your first camera" }).click();
  await page
    .getByLabel("Camera name", { exact: true })
    .fill("Warehouse entrance");
  await page
    .getByLabel("Main stream URL", { exact: true })
    .fill("rtsp://user:secret@192.0.2.10/live");
  await page.getByRole("button", { name: "Save camera" }).click();
  await expect(page.getByRole("alert")).toContainText(
    "enter username and password separately",
  );
  await page
    .getByLabel("Main stream URL", { exact: true })
    .fill("rtsp://192.0.2.10/live");
  await page.getByLabel("Camera username").fill("operator");
  await page.getByLabel("Camera password").fill("browser-test-camera-secret");
  await page.getByRole("button", { name: "Save camera" }).click();
  await expect(
    page.getByRole("heading", { name: "Warehouse entrance", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("Not checked yet")).toBeVisible();
  await page.getByRole("button", { name: "Check main stream" }).click();
  await expect(page.getByText("1920 × 1080 · h264")).toBeVisible();
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({
    path: "test-results/camera-workspace.png",
    fullPage: true,
  });
  expect(await page.evaluate(() => localStorage.length)).toBe(0);
  expect(await page.evaluate(() => sessionStorage.length)).toBe(0);
  await page.reload();
  await expect(
    page.getByRole("heading", { name: "Unlock your workspace" }),
  ).toBeVisible();
  await page.getByLabel("Local access key").fill(accessKey);
  await page.getByRole("button", { name: "Unlock workspace" }).click();
  await expect(page.getByText("1920 × 1080 · h264")).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth),
  ).toBeLessThanOrEqual(390);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({
    path: "test-results/camera-workspace-mobile.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "Remove Warehouse entrance" }).click();
  await page.getByRole("button", { name: "Keep camera" }).click();
  await expect(
    page.getByRole("heading", { name: "Warehouse entrance", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Remove Warehouse entrance" }).click();
  await page
    .getByRole("button", { name: "Remove camera", exact: true })
    .click();
  await expect(page.getByText("A clearer view starts here")).toBeVisible();
});
