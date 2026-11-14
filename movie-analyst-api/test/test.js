process.env.NODE_ENV = 'test';
// No database in tests: point the pool at a closed port so queries fail fast.
process.env.DB_HOST = '127.0.0.1';
process.env.DB_PORT = '1';

//Require the dev-dependencies
let chai = require('chai');
let chaiHttp = require('chai-http');
let server = require('../server');
let should = chai.should();

chai.use(chaiHttp);
//Our parent block
describe('API', () => {

/*
  * Test the /GET route
  */
  describe('/GET home', () => {
      it('it should GET any reply', (done) => {
        chai.request(server)
            .get('/')
            .end((err, res) => {
                res.should.have.status(200);
              done();
            });
      });
  });

  // Regression: a typo in the error handler used to kill the whole process here.
  describe('/GET movies without a database', () => {
      it('it should answer 500 and keep the process alive', (done) => {
        chai.request(server)
            .get('/movies')
            .end((err, res) => {
                res.should.have.status(500);
                chai.request(server).get('/').end((err2, res2) => {
                    res2.should.have.status(200);
                  done();
                });
            });
      });
  });

});
