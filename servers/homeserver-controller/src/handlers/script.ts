import { FastifyReply, FastifyRequest } from "fastify";
import execa from "execa";
import path from "path";

export const scriptHandler = async (
  request: FastifyRequest,
  reply: FastifyReply
) => {
  const { name, args } = request.body as { name: string; args?: string };
  const Authorization = request.headers.authorization;
  const HOMESERVER_TOKEN = process.env.HOMESERVER_TOKEN ?? "";

  if (HOMESERVER_TOKEN === "") {
    return reply.status(403).send({ message: "Unauthorized" });
  }

  if (Authorization !== `Bearer ${HOMESERVER_TOKEN}`) {
    return reply.status(403).send({ message: "Unauthorized" });
  }

  const cwd = path.join(__dirname, "..", "..", "..", "..");
  const scriptPath = `/Users/creco/workspaces/homeserver/servers/homeserver-controller/scripts/${name}.sh`;

  console.log(`스크립트: ${name}`);

  const KEY_PATH = process.env.KEY_PATH || "~/.ssh/ci_id_rsa";

  const result = execa(
    "ssh",
    [
      "-i",
      KEY_PATH,
      "-o",
      "StrictHostKeyChecking=accept-new",
      "creco@creaticoding.iptime.org",
      "bash",
      scriptPath,
      ...(args == null ? [] : [args]),
    ],
    { cwd }
  );

  reply.status(200).send({ message: "OK", data: { name } });

  const awaitedResult = await result;
  console.log(awaitedResult.stdout);

  if (awaitedResult.stderr) {
    console.log(awaitedResult.stderr);
  }
};
