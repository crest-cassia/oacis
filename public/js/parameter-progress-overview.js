var margin = {top: 80, right: 0, bottom: 10, left: 80},
    width = 720,
    height = 720;

var x = d3.scale.ordinal().rangeBands([0, width]),
    y = d3.scale.ordinal().rangeBands([0, height]),
    z = d3.scale.linear().domain([0, 4]).clamp(true),
    c = d3.scale.category10().domain(d3.range(10));

var svg = d3.select("body").append("svg")
    .attr("id", "canvas")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    // .style("margin-left", -margin.left + "px")
  .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

var divpopup = d3.select("body").append("div")
    .attr("id", "popup")
    .style("position", "absolute")
    .style("color", "white")
    .style("font-size", "14px")
    .style("background", "rgba(0,0,0,0.5)")
    .style("padding", "5px 10px 5px 10px")
    .style("-moz-border-radius", "5px 5px")
    .style("border-radius", "5px 5px")
    .style("z-index", "10")
    .style("visibility", "hidden");

divpopup.append("div")
    .attr("id", "popup-title")
    .style("font-size", "15px")
    .style("width", "200px")
    .style("margin-bottom", "4px")
    .style("font-weight", "bolder");

divpopup.append("div")
    .attr("id", "popup-content")
    .style("font-size", "12px");

divpopup.append("div")
    .attr("id", "popup-desc")
    .style("font-size", "14px");

function hslcolor(h, s, l) {
  return d3.hsl(h, s, l).toString();
}

function pcolormap(v) {
  // return hslcolor(v * 180.0 + 180.0, 0.7 * v, 0.9 - v * 0.6);
  return hslcolor(v * 180.0, 0.7 * v, 0.9 - v * 0.6);
  // return hslcolor(v * 180.0 + 180.0, 0.7 * v, 0.5);
}

var cmap = d3.select('#color-map').append("svg")
    .attr("id", "color-map-svg")
    .attr("width", 200)
    .attr("height", 20);
for (var i = 0.0; i < 10.0; i += 1.0) {
    cmap.append("rect")
        .attr("class", "cell")
        .attr("x", i * 20.0)
        .attr("y", 0.0)
        .attr("width", 19)
        .attr("height", 19)
        .style("fill", function(d) {
          return pcolormap(i / 10.0);});
          //return d3.hsl(i * 360.0 / 10.0, 0.8, 0.5).toString();});
}

var parameters = [],
total_parameters = 0
finished_parameters = 0,
progress = [];

// load_parameter_progress("data/parameter-progress-sample.json");
// load_parameter_progress("http://localhost:4567/parameter-progress.json");
// load_parameter_progress("parameter-progress-overview.json");
load_parameter_progress("http://localhost:3000/simulators/522d751f899e533149000002/_progress.json");

function load_parameter_progress(url) {

  d3.json(url, function(json) {

    total_parameters = json.total_parameters;
    finished_parameters = json.finished_parameters;
    json.parameters;

    json.parameters.forEach(function(v, i) {
      parameters.push({name : v.name, values : v.values});
      d3.select('#row-parameter').append('option').text(v.name);
      d3.select('#column-parameter').append('option').text(v.name);
    });

    // set default selection
    if (parameters.length > 1) {
      // <<< [2013/08/30 I.Noda]
      // switch row and column order
      //d3.select('#column-parameter').node().selectedIndex = 1;
      d3.select('#row-parameter').node().selectedIndex = 1;
      // >>> [2013/08/30 I.Noda]
    }

    progress = json.progress;

    d3.select('#total-parameters').text(d3.select('#total-parameters').text() + total_parameters);
    d3.select('#finished-parameters').text(d3.select('#finished-parameters').text() + finished_parameters);

    update();

    function update() {
      var row_i = d3.select('#row-parameter').node().selectedIndex;
      var row_v = d3.select('#row-parameter').node().options[row_i].value;

      var column_i = d3.select('#column-parameter').node().selectedIndex;
      var column_v = d3.select('#column-parameter').node().options[column_i].value;

      var rows = [];
      parameters.forEach(function (v, i) {
        if (v.name == row_v) {
          v.values.forEach(function (val, j) {
            rows.push({name : v.name, value : val});
          });
        }
      });
      // <<< [2013/08/30 I.Noda]
      rows = rows.reverse() ;
      // >>> [2013/08/30 I.Noda]

      var columns = [];
      parameters.forEach(function (v, i) {
        if (v.name == column_v) {
          v.values.forEach(function (val, j) {
            columns.push({name : v.name, value : val});
          });
        }
      });

      pmatrix = [];
      rows.forEach(function(r, i) {
        pmatrix[i] = d3.range(columns.length).map(function(j) { return {x: j, y: i, z: 0}; });
      });
      rows.forEach(function(r, i) {
        columns.forEach(function(c, j) {
          progress.forEach(function(p, k) {
            if (p.parameter_pair[0] == r.name && p.parameter_pair[1] == c.name) {
              p.each_finish.forEach(function(e, l) {
                if (e.value[0] == r.value && e.value[1] == c.value) {
                  pmatrix[i][j].z = e.finish / p.total;
                }
              });
            } else if (p.parameter_pair[1] == r.name && p.parameter_pair[0] == c.name) {
              p.each_finish.forEach(function(e, l) {
                if (e.value[0] == r.value && e.value[1] == c.value) {
                  pmatrix[j][i].z = e.finish / p.total;
                }
              });
            }
          });
        });
      });

      var xdomain = [];
      var ydomain = [];
      rows.forEach(function(r, i) {
        return ydomain.push(i);
      });
      columns.forEach(function(c, i) {
        return xdomain.push(i);
      });
      x.domain(xdomain);
      y.domain(ydomain);

      // remove previous drawing
      var oldsvg = d3.select("#canvas").selectAll("rect");
      if (oldsvg.length > 0) {
        if (oldsvg[0].length > 0) {
          oldsvg.remove();
        }
      }
      var oldrow = d3.select("#canvas").selectAll(".row");
      if (oldrow.length > 0) {
        if (oldrow[0].length > 0) {
          oldrow.remove();
        }
      }
      var oldcolumn = d3.select("#canvas").selectAll(".column");
      if (oldcolumn.length > 0) {
        if (oldcolumn[0].length > 0) {
          oldcolumn.remove();
        }
      }

      //drawcolormap();

      svg.append("rect")
          .attr("class", "background")
          .attr("width", width)
          .attr("height", height);

      var row = svg.selectAll(".row")
          .data(pmatrix)
        .enter().append("g")
          .attr("class", "row")
          .attr("transform", function(d, i) { return "translate(0," + y(i) + ")"; })
          .each(row);

      row.append("line")
          .attr("x2", width);

      row.append("text")
          .attr("x", -6)
          .attr("y", y.rangeBand() / 2)
          .attr("dy", ".32em")
          .attr("text-anchor", "end")
          .text(function(d, i) { return rows[i].name + ' : ' + rows[i].value; });

      var cmatrix = [];
      for (var i = 0; i < columns.length; i++) {
        tmparray = [];
        for (var j = 0; j < rows.length; j++) {
          tmparray.push(pmatrix[j][i]);
        }
        cmatrix.push(tmparray);
      }

      var column = svg.selectAll(".column")
          .data(cmatrix)
        .enter().append("g")
          .attr("class", "column")
          .attr("transform", function(d, i) { return "translate(" + x(i) + ")rotate(-90)"; });

      column.append("line")
          .attr("x1", -height);

      column.append("text")
          .attr("x", 6)
          .attr("y", x.rangeBand() / 2)
          .attr("dy", ".32em")
          .attr("text-anchor", "start")
          .text(function(d, i) { return columns[i].name + ' : ' + columns[i].value; });

      function row(row) {
        var cell = d3.select(this).selectAll(".cell")
            //.data(row.filter(function(d) { return d.z; }))
            .data(row)
          .enter().append("rect")
            .attr("class", "cell")
            .attr("x", function(d) { return x(d.x); })
            .attr("width", x.rangeBand())
            .attr("height", y.rangeBand())
            .style("fill-opacity", function(d) { return z(d.z); })
            .style("fill-opacity", 0.8)
            .style("fill", function(d) { return pcolormap(d.z);})
            .on("mouseover", function(d) {
              d3.selectAll(".row text").classed("active", function(d, i) { return i == d.y; });
              d3.selectAll(".column text").classed("active", function(d, i) { return i == d.x; });

              function vlength(name) {
                for (var i = 0; i < parameters.length; i++) {
                  if (parameters[i].name == name)
                    return parameters[i].values.length;
                }
              }
              divpopup.selectAll("#popup-title").text("Parameter (" + rows[d.y].name + ":" + rows[d.y].value + ", " + columns[d.x].name + ":" + columns[d.x].value + ")");
              var rown = vlength(rows[d.y].name);
              var columnn = vlength(columns[d.x].name);
              var totaln = (total_parameters / rown / columnn).toFixed(0);
              var executedn = (totaln * d.z).toFixed(0);
              divpopup.selectAll("#popup-content").text("Executed/Total: " +  executedn+ "/" + totaln);
              divpopup.selectAll("#popup-desc").text("Progress: " + (d.z * 100.0).toFixed(3) + "%");
              divpopup
                .style("visibility", "visible");
             })
            .on("mousemove", function(d) {
              console.log(event);
              divpopup.style("left", (event.clientX - margin.left) +  "px")
                  .style("top", event.clientY + "px");
              //divpopup.style("top", (event.pageY - 110) + "px")
              //  .style("left", (event.pageX + -380) + "px");
            })
            .on("mouseout", function(d) {
              d3.selectAll("text").classed("active", false);
              divpopup
                .style("visibility", "hidden");
            })
      }
    }

    d3.select('#row-parameter').on('change', function() {
      update();
    });

    d3.select('#column-parameter').on('change', function() {
      update();
    });
  });
}

// d3.select(self.frameElement).style("height", (height + margin.top + margin.bottom) + "px");
d3.select(self.frameElement).style("height", height + "px");
