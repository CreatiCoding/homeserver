import { FastifyReply, FastifyRequest } from "fastify";
import execa from "execa";
import path from "path";
import fs from "fs";

const HOMESERVER_TOKEN = process.env.HOMESERVER_TOKEN;

export const scriptHandler = async (
  request: FastifyRequest,
  reply: FastifyReply
) => {
  const { name } = request.body as { name: string };
  const Authorization = request.headers.authorization;

  if (Authorization !== `Bearer ${HOMESERVER_TOKEN}`) {
    return reply.status(403).send({ message: "Unauthorized" });
  }

  const cwd = path.join(__dirname, "..", "..");

  if (!fs.existsSync(path.join(cwd, `./scripts/${name}.sh`))) {
    return reply.status(404).send({ message: "Not Found" });
  }

  const script = await execa("bash", ["-c", `./scripts/${name}.sh`], { cwd });

  return reply
    .status(200)
    .send({ message: "OK", data: { output: script.stdout } });
};
