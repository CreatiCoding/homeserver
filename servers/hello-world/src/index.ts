import { Hono } from "hono";

const app = new Hono();

app.get("/", (c) => c.text("Hello World"));

export default {
  port: Number(process.env.PORT ?? 3000),
  fetch: app.fetch,
};
