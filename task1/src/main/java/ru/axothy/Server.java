package ru.axothy;

import one.nio.http.HttpServer;
import one.nio.http.HttpServerConfig;
import one.nio.http.HttpSession;
import one.nio.http.Path;
import one.nio.http.Request;
import one.nio.http.Response;
import one.nio.server.AcceptorConfig;

import java.io.IOException;

/**
 * One-nio http server
 */
public class Server extends HttpServer {
    private static final int BASE_PORT = 8888;

    public Server(int port) throws IOException {
        super(createConfig(port));
    }

    @Path("/status")
    public Response status() {
        return Response.ok("OK");
    }

    @Override
    public void handleRequest(Request request, HttpSession session) throws IOException {
        try {
            super.handleRequest(request, session);
        } catch (RuntimeException e) {
            session.sendError(Response.BAD_REQUEST, e.toString());
        }
    }

    private static HttpServerConfig createConfig(int port) {
        HttpServerConfig httpServerConfig = new HttpServerConfig();
        AcceptorConfig acceptorConfig = new AcceptorConfig();
        acceptorConfig.reusePort = true;
        acceptorConfig.port = port;

        httpServerConfig.acceptors = new AcceptorConfig[]{acceptorConfig};
        httpServerConfig.closeSessions = true;
        return httpServerConfig;
    }


    public static void main(String[] args) throws IOException {
        int port;

        if (args.length > 0) {
            port = Integer.parseInt(args[0]);
        } else {
            port = BASE_PORT;
        }

        Server server = new Server(port);
        server.start();
    }
}
