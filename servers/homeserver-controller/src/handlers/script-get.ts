import { FastifyReply, FastifyRequest } from "fastify";
import execa from "execa";
import path from "path";
import fs from "fs";

export const scriptGetHandler = async (
  request: FastifyRequest<{ Params: { name: string } }>,
  reply: FastifyReply
) => {
  const { name } = request.params;

  const cwd = path.join(__dirname, "..", "..", "..", "..");
  const scriptPath = `/Users/creco/workspaces/homeserver/servers/homeserver-controller/read-scripts/${name}.sh`;

  console.log(`스크립트: ${name}`);

  const KEY_PATH = process.env.KEY_PATH || "~/.ssh/ci_id_rsa";
  try {
    const { stdout } = await execa(
      "ssh",
      [
        "-i",
        KEY_PATH,
        "-o",
        "StrictHostKeyChecking=accept-new",
        "creco@creaticoding.iptime.org",
        "bash",
        scriptPath,
      ],
      { cwd, stdio: "inherit" }
    );

    return reply.status(200).send(stdout);
  } catch (error: any) {
    console.log(error.message);
    reply.status(400).send(error.message);
    return;
  }
};
