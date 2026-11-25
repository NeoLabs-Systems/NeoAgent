// Package neorouterapi connects NeoAgent to a NeoRouter: the "Connect
// NeoRouter" settings routes (/api/neorouter), the device sign-in that fetches
// a key, the router's connection (the server's own, set by an admin, or a
// person's), what the router offers per role, and the client that calls its
// OpenAI-style API.
//
// The AI engine uses Service to find the connection for a role and to call the
// router (models, embeddings, images, search).
package neorouterapi
