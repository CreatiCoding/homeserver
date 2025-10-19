import { FastifyReply, FastifyRequest } from "fastify";

export const healthHandler = async (_: FastifyRequest, __: FastifyReply) => {
  return { hello: "world" };
};
