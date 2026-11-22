// Declare our dependencies
var express = require('express');
var request = require('superagent');

// Create our express app
var app = express();

// Set the view engine to use EJS as well as set the default views directory
app.set('view engine', 'ejs');
app.set('views', __dirname + '/public/views/');

// No static middleware: public/ only holds the templates, and serving it made their source
// downloadable (/views/index.ejs). CSS and fonts come from a CDN.
app.disable('x-powered-by');

let backend_url = process.env.BACKEND_URL || "localhost:3000"

// Home page: static, does not call the API.
app.get('/', function(req, res){
  res.render('index');
})

// Each data page asks the API (through the internal load balancer) and renders the result.
// There is no login: these routes are public, like the API behind them.
app.get('/movies', function(req, res){
  request
    .get(`http://${backend_url}/movies`)
    .end(function(err, data) {
      // No response (timeout, DNS) or an error from the API: there is no list to render.
      if(!data || (!data.ok && data.status != 403)) return res.status(502).send('Backend unavailable');
      if(data.status == 403){
        res.send(403, '403 Forbidden');
      } else {
        var movies = data.body;
        res.render('movies', { movies: movies} );
      }
    })
})

// The page is /authors, but the API calls them reviewers.
app.get('/authors', function(req, res){
  request
    .get(`http://${backend_url}/reviewers`)
    .end(function(err, data) {
      if(!data || (!data.ok && data.status != 403)) return res.status(502).send('Backend unavailable');
      if(data.status == 403){
        res.send(403, '403 Forbidden');
      } else {
        var authors = data.body;
        res.render('authors', {authors : authors});
      }
    })
})

app.get('/publications', function(req, res){
  request
    .get(`http://${backend_url}/publications`)
    .end(function(err, data) {
      if(!data || (!data.ok && data.status != 403)) return res.status(502).send('Backend unavailable');
      if(data.status == 403){
        res.send(403, '403 Forbidden');
      } else {
        var publications = data.body;
        res.render('publications', {publications : publications});
      }
    })
})

app.listen(process.env.PORT || 3030);