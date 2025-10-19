import Fastify from "fastify";
import { healthHandler } from "./handlers/health";
import { scriptHandler } from "./handlers/script";
import dotenv from "dotenv";

dotenv.config();

const fastify = Fastify({ logger: false });
const { PORT = "", APIPREFIX = "" } = process.env;
const port = PORT === "" ? 3000 : parseInt(PORT);
const apiPrefix = APIPREFIX === "" ? "/homeserver-controller" : APIPREFIX;

async function main() {
  fastify.register(
    async function (router) {
      router.post("/script", scriptHandler);
      router.get("/health", healthHandler);
    },
    { prefix: apiPrefix }
  );

  await fastify.listen({
    port,
    host: "0.0.0.0",
  });

  console.log(`Server is running on port ${port} http://localhost:${port}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
