'use strict';

const supertest = require('supertest');

function agent(app) {
  return supertest.agent(app);
}

function request(app) {
  return supertest(app);
}

module.exports = {
  agent,
  request,
};
