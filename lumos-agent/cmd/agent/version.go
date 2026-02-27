package main

// AgentVersion can be overridden at build time via:
// go build -ldflags "-X main.AgentVersion=vX.Y.Z"
var AgentVersion = "dev"

// CompatibleAppRange declares which app semantic versions are supported by
// this agent build. Format accepts comparator tokens, for example:
// ">=1.0.0,<2.0.0"
// This can be overridden at build time via:
// go build -ldflags "-X main.CompatibleAppRange=>=1.0.0,<2.0.0"
var CompatibleAppRange = ">=1.0.0,<2.0.0"
