import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { apply } from "../roles/deepseek_harness/files/dsh-auth-bootstrap/lib/index.js";

const originalEnvironment = {
  publicUrl: process.env.DSH_AUTH_BOOTSTRAP_PUBLIC_URL,
  route: process.env.DSH_AUTH_BOOTSTRAP_ROUTE,
  secret: process.env.DSH_AUTH_BOOTSTRAP_SECRET,
};

const secret = "a".repeat(64);
let currentToken = "first-token";
let registeredRoute;
let disposed = false;

before(() => {
  process.env.DSH_AUTH_BOOTSTRAP_PUBLIC_URL = "https://dsh.example.test/";
  process.env.DSH_AUTH_BOOTSTRAP_ROUTE = "/__las/dsh-auth-bootstrap";
  process.env.DSH_AUTH_BOOTSTRAP_SECRET = secret;

  apply({
    connection: {
      authenticatedUrl(baseUrl) {
        return `${baseUrl}?token=${currentToken}`;
      },
    },
    effect(register) {
      const dispose = register();
      assert.equal(typeof dispose, "function");
    },
    webServer: {
      register(route) {
        registeredRoute = route;
        return () => {
          disposed = true;
        };
      },
    },
  });
});

after(() => {
  for (const [name, value] of Object.entries({
    DSH_AUTH_BOOTSTRAP_PUBLIC_URL: originalEnvironment.publicUrl,
    DSH_AUTH_BOOTSTRAP_ROUTE: originalEnvironment.route,
    DSH_AUTH_BOOTSTRAP_SECRET: originalEnvironment.secret,
  })) {
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
});

function responseRecorder() {
  const headers = new Map();
  return {
    ended: false,
    headers,
    statusCode: 0,
    end() {
      this.ended = true;
    },
    setHeader(name, value) {
      headers.set(name.toLowerCase(), value);
    },
  };
}

function request(overrides = {}) {
  return {
    headers: { "x-las-dsh-auth-bootstrap-secret": secret },
    method: "GET",
    socket: { remoteAddress: "127.0.0.1" },
    ...overrides,
  };
}

test("registers one exact bootstrap route", () => {
  assert.equal(registeredRoute.kind, "exact");
  assert.equal(registeredRoute.path, "/__las/dsh-auth-bootstrap");
  assert.equal(disposed, false);
});

test("returns the current process authenticated URL without caching", () => {
  const firstResponse = responseRecorder();
  registeredRoute.handler(request(), firstResponse);
  assert.equal(firstResponse.statusCode, 303);
  assert.equal(firstResponse.headers.get("location"), "https://dsh.example.test/?token=first-token");
  assert.equal(firstResponse.headers.get("cache-control"), "no-store");
  assert.equal(firstResponse.headers.get("referrer-policy"), "no-referrer");

  currentToken = "second-token";
  const secondResponse = responseRecorder();
  registeredRoute.handler(request(), secondResponse);
  assert.equal(secondResponse.headers.get("location"), "https://dsh.example.test/?token=second-token");
});

test("rejects non-loopback, wrong-secret, and non-GET requests", () => {
  const cases = [
    [request({ socket: { remoteAddress: "192.0.2.10" } }), 403],
    [request({ headers: { "x-las-dsh-auth-bootstrap-secret": "b".repeat(64) } }), 403],
    [request({ method: "POST" }), 405],
  ];

  for (const [incomingRequest, expectedStatus] of cases) {
    const response = responseRecorder();
    registeredRoute.handler(incomingRequest, response);
    assert.equal(response.statusCode, expectedStatus);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.ended, true);
  }
});
