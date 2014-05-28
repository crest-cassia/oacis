function draw_line_plot(url, parameter_set_base_url, current_ps_id) {

  var margin = {top: 10, right: 100, bottom: 100, left: 100},
    width = 560;
    height = 460;

  var row = d3.select("#plot").insert("div","div").attr("class", "row");
  var plot_region = row.append("div").attr("class", "span8");
  var description = row.append("div").attr("class", "span4");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom
    })
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var xScale;
    var yScale;

    if (dat.xscale == "linear") {
      xScale = d3.scale.linear().range([0, width]);
    } else if (dat.xscale == "log") {
      xScale = d3.scale.log().range([0, width]);
    } else {
      alert("xscale:"+ dat.xscale +" is not defined.");
      xScale = d3.scale.linear().range([0, width]);
    }
    if (dat.yscale == "linear") {
      yScale = d3.scale.linear().range([height, 0]);
    } else if (dat.yscale == "log") {
      yScale = d3.scale.log().range([height, 0]);
    } else {
      alert("yscale:"+ dat.yscale +" is not defined.");
      yScale = d3.scale.linear().range([height, 0]);
    }


    xScale.domain([
      d3.min( dat.data, function(r) { return d3.min(r, function(v) { return v[0];})}),
      d3.max( dat.data, function(r) { return d3.max(r, function(v) { return v[0];})})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];}) }),
      d3.max( dat.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];}) })
    ]).nice();

    // X-Axis
    var xAxis = d3.svg.axis()
      .scale(xScale)
      .orient("bottom");
    svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis)
      .append("text")
        .style("text-anchor", "middle")
        .attr("x", width / 2.0)
        .attr("y", 50.0)
        .text(dat.xlabel);

    // Y-Axis
    var yAxis = d3.svg.axis()
      .scale(yScale)
      .orient("left");
    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("x", -height/2)
        .attr("y", -50.0)
        .style("text-anchor", "middle")
        .text(dat.ylabel);

    // group for each series
    var series = svg
      .selectAll(".series")
      .data(dat.data)
      .enter().append("g")
        .attr("class", "series");

    // draw line plot
    var colorScale = d3.scale.category10();
    var line = d3.svg.line()
      .x( function(d) { return xScale(d[0]);} )
      .y( function(d) { return yScale(d[1]);} );
    series.append("path")
      .attr("class", "line")
      .attr("d", function(d) { return line(d);} )
      .style({
        "stroke": function(d, i) { return colorScale(i);},
        "fill": "none",
        "stroke-width": "1.5px"
      });

    // draw circles
    var tooltip = d3.select("#plot-tooltip");
    var point = series.selectAll("circle")
      .data(function(d,i) {
        return d.map(function(v) {
          return {
            x: v[0], y: v[1], yerror: v[2],
            series_index: i, series_value: dat.series_values[i], psid: v[3]
          };
        });
      }).enter();
    point.append("circle")
      .attr("cx", function(d) { return xScale(d.x);})
      .attr("cy", function(d) { return yScale(d.y);})
      .style("fill", function(d) { return colorScale(d.series_index);})
      .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", .8);
        tooltip.html(
          dat.xlabel + " : " + d.x + "<br/>" +
          dat.ylabel + " : " + Math.round(d.y*1000000)/1000000 +
          " (" + Math.round(d.yerror*1000000)/1000000 + ")<br/>" +
          (dat.series ? (dat.series + " : " + d.series_value + "<br/>") : "") +
          "ID: " + d.psid);
      })
      .on("mousemove", function() {
        tooltip
          .style("top", (d3.event.pageY-10) + "px")
          .style("left", (d3.event.pageX+10) + "px");
      })
      .on("mouseout", function() {
        tooltip.transition()
          .duration(300)
          .style("opacity", 0);
      })
      .on("dblclick", function(d) {
        // open a link in a background window
        window.open(parameter_set_base_url + d.psid, '_blank');
      });

    // draw error bar
    point.insert("line", "circle")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return xScale(d.x);},
        x2: function(d) { return xScale(d.x);},
        y1: function(d) { return yScale(d.y - d.yerror);},
        y2: function(d) { return yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    point.insert("line", "circle")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return xScale(d.x) - 3;},
        x2: function(d) { return xScale(d.x) + 3;},
        y1: function(d) { return yScale(d.y - d.yerror);},
        y2: function(d) { return yScale(d.y - d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    point.insert("line", "circle")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return xScale(d.x) - 3;},
        x2: function(d) { return xScale(d.x) + 3;},
        y1: function(d) { return yScale(d.y + d.yerror);},
        y2: function(d) { return yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });

    // draw legend title
    svg.append("text")
      .attr({
        x: width,
        y: 0,
        dx: ".8em",
        dy: ".8em"
      })
      .text(dat.series);

    // draw legend
    var legend = svg.append("g")
      .attr("class", "legend")
      .attr("transform", "translate(" + width + "," + 20 + ")");
    var legendItem = legend.selectAll("g")
      .data(dat.series_values)
      .enter().append("g")
      .attr("class", "legend-item")
      .attr("transform", function(d,i) {
        return "translate(10," + (i*20) + ")";
      });
    legendItem.append("rect")
      .attr("width", 15)
      .attr("height", 15)
      .style("fill", function(d,i) { return colorScale(i);});
    legendItem.append("text")
      .attr("x", 20)
      .attr("y", 7.5)
      .attr("dy", "0.3em")
      .text( function(d,i) { return d; });

    // description for the specification of the plot
    var dl = description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(dat.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(dat.ylabel);
    if(dat.series) {
      dl.append("dt").text("Series");
      dl.append("dd").text(dat.series);
    }
    description.append("a").attr({target: "_blank", href: url}).text("show data in json");
    description.append("br");
    plt_url = url.replace(/\.json/, '.plt')
    description.append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
    description.append("br")
    description.append("a").text("delete plot").on("click", function() {
      row.remove();
    });
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    row.remove();
  });
}

function draw_scatter_plot(url, parameter_set_base_url, current_ps_id) {
  var margin = {top: 10, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;

  var row = d3.select("#plot").insert("div","div").attr("class", "row");
  var plot_region = row.append("div").attr("class", "span8");
  var description = row.append("div").attr("class", "span4");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom
    });
  var colorMapG = svg.append("g")
    .attr("transform", "translate(" + (margin.left + width) + "," + margin.top + ")");
  var svg = svg.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var xScale;
    var yScale;

    if (dat.xscale == "linear") {
      xScale = d3.scale.linear().range([0, width]);
    } else if (dat.xscale == "log") {
      xScale = d3.scale.log().range([0, width]);
    } else {
      alert("xscale:"+ dat.xscale +" is not defined.");
      xScale = d3.scale.linear().range([0, width]);
    }
    if (dat.yscale == "linear") {
      yScale = d3.scale.linear().range([height, 0]);
    } else if (dat.yscale == "log") {
      yScale = d3.scale.log().range([height, 0]);
    } else {
      alert("yscale:"+ dat.yscale +" is not defined.");
      yScale = d3.scale.linear().range([height, 0]);
    }

    var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
    var colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
    var xlabel = dat.xlabel;
    var ylabel = dat.ylabel;

    xScale.domain([
      d3.min( dat.data, function(d) { return d[0][xlabel];}),
      d3.max( dat.data, function(d) { return d[0][xlabel];})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(d) { return d[0][ylabel];}),
      d3.max( dat.data, function(d) { return d[0][ylabel];})
    ]).nice();
    var result_min_val = d3.min( dat.data, function(d) { return d[1];});
    var result_max_val = d3.max( dat.data, function(d) { return d[1];});
    colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
    colorScalePoint.domain( colorScale.domain() ).nice();

    function draw_color_map(g) {
      var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(colorScale.range());
      g.append("text")
        .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
        .style("text-anchor", "begin")
        .text("Result");
      g.selectAll("rect")
        .data([1.0, 0.8, 0.6, 0.4, 0.2, 0.0])
        .enter().append("rect")
        .attr({
          x: 10.0,
          y: function(d,i) { return i * 20.0 + 20.0; },
          width: 19,
          height: 19,
          fill: function(d) { return scale(d); }
        });
      g.append("text")
        .attr({x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[2] );
      g.append("text")
        .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[0] );
    }
    draw_color_map(colorMapG);

    function draw_voronoi_heat_map() {
      // add noise to coordinates of vertices in order to prevent hang-up.
      // hanging-up sometimes happen when duplicated points are included.
      var vertices = dat.data.map(function(v) {
        return [
          xScale(v[0][xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
          yScale(v[0][ylabel]) + Math.random() * 1.0 - 0.5
        ];
      });
      var voronoi = d3.geom.voronoi()
        .clipExtent([[0, 0], [width, height]]);
      var path = svg.append("g").selectAll("path")
        .data(voronoi(vertices));
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(dat.data[i][1]);})
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .style("fill-opacity", 0.7)
        .style("stroke", "none");
    }
    try {
      draw_voronoi_heat_map();
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }

    function draw_axes(xlabel, ylabel) {
      // X-Axis
      var xAxis = d3.svg.axis()
        .scale(xScale)
        .orient("bottom");
      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
        .append("text")
          .style("text-anchor", "middle")
          .attr("x", width / 2.0)
          .attr("y", 50.0)
          .text(xlabel);

      // Y-Axis
      var yAxis = d3.svg.axis()
        .scale(yScale)
        .orient("left");
      svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("x", -height/2)
          .attr("y", -50.0)
          .style("text-anchor", "middle")
          .text(ylabel);
    }
    draw_axes(dat.xlabel, dat.ylabel);

    function draw_points() {
      var tooltip = d3.select("#plot-tooltip");
      var mapped = dat.data.map(function(v) {
        return {
          x: v[0][xlabel], y: v[0][ylabel],
          average: v[1], error: v[2], psid: v[3]
        };
      });
      var point = svg.selectAll("circle")
        .data(mapped).enter();
      point.append("circle")
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function(d) { return colorScalePoint(d.average);})
        .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;})
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", .8);
          tooltip.html(
            dat.xlabel + " : " + d.x + "<br/>" +
            dat.ylabel + " : " + d.y + "<br/>" +
            "Result : " + Math.round(d.average*1000000)/1000000 +
            " (" + Math.round(d.error*1000000)/1000000 + ")<br/>" +
            "ID: " + d.psid);
        })
        .on("mousemove", function() {
          tooltip
            .style("top", (d3.event.pageY-10) + "px")
            .style("left", (d3.event.pageX+10) + "px");
        })
        .on("mouseout", function() {
          tooltip.transition()
            .duration(300)
            .style("opacity", 0);
        })
        .on("dblclick", function(d) {
          // open a link in a background window
          window.open(parameter_set_base_url + d.psid, '_blank');
        });
    }
    draw_points();

    function add_description() {
      // description for the specification of the plot
      var dl = description.append("dl");
      dl.append("dt").text("X-Axis");
      dl.append("dd").text(dat.xlabel);
      dl.append("dt").text("Y-Axis");
      dl.append("dd").text(dat.ylabel);
      dl.append("dt").text("Result");
      dl.append("dd").text(dat.result);
      description.append("a").attr({target: "_blank", href: url}).text("show data in json");
      description.append("br");
      description.append("a").text("delete plot").on("click", function() {
        row.remove();
      });
    }
    add_description();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    row.remove();
  });
}

function draw_figure_viewer(url, parameter_set_base_url, current_ps_id) {
  var margin = {top: 10, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;
  var image_scale = "middle";

  var row = d3.select("#plot").insert("div","div").attr("class", "row");
  var plot_region = row.append("div").attr("class", "span8");
  var description = row.append("div").attr("class", "span4");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom
    });
  var svg = svg.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var xScale = d3.scale.linear().range([0, width]);
    var yScale = d3.scale.linear().range([height, 0]);

    xScale.domain([
      d3.min( dat.data, function(d) { return d[0];}),
      d3.max( dat.data, function(d) { return d[0];})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(d) { return d[1];}),
      d3.max( dat.data, function(d) { return d[1];})
    ]).nice();

    function draw_axes(xlabel, ylabel) {
      // X-Axis
      var xAxis = d3.svg.axis()
        .scale(xScale)
        .orient("bottom");
      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
        .append("text")
          .style("text-anchor", "middle")
          .attr("x", width / 2.0)
          .attr("y", 50.0)
          .text(xlabel);

      // Y-Axis
      var yAxis = d3.svg.axis()
        .scale(yScale)
        .orient("left");
      svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("x", -height/2)
          .attr("y", -50.0)
          .style("text-anchor", "middle")
          .text(ylabel);
    }
    draw_axes(dat.xlabel, dat.ylabel);

    var mapped = dat.data.map(function(v) {
      return { x: v[0], y: v[1], path:v[2], psid: v[3] };
    });

    function draw_figures() {
      var tooltip = d3.select("#plot-tooltip");
      var imgs = svg.selectAll("image").data(mapped).enter();
      imgs.append("svg:image")
        .attr("x", function(d) { return xScale(d.x);})
        .attr("y", function(d) { return yScale(d.y);})
        .attr("xlink:href", function(d) {return d.path})
        .attr("width", width/10)
        .attr("height", height/10)
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", .8);
          tooltip.html(
            dat.xlabel + " : " + d.x + "<br/>" +
            dat.ylabel + " : " + d.y + "<br/>" +
            "ID: " + d.psid + "<br />" +
            '<img src="' + d.path + '" width="300px" />');
        })
        .on("mousemove", function() {
          tooltip
            .style("top", (d3.event.pageY) + "px")
            .style("left", (d3.event.pageX+10) + "px");
        })
        .on("mouseout", function() {
          tooltip.transition()
            .duration(300)
            .style("opacity", 0);
        })
        .on("dblclick", function(d) {
          window.open(parameter_set_base_url + d.psid, '_blank');
        });
    }
    draw_figures();

    function add_description() {
      // description for the specification of the plot
      var dl = description.append("dl");
      dl.append("dt").text("X-Axis");
      dl.append("dd").text(dat.xlabel);
      dl.append("dt").text("Y-Axis");
      dl.append("dd").text(dat.ylabel);
      dl.append("dt").text("Result");
      dl.append("dd").text(dat.result);
      description.append("a").attr({target: "_blank", href: url}).text("show data in json");
      description.append("br");
      var tooltip = d3.select("#plot-tooltip");
      description.append("a").text("show small image").on("click", function() {
        if(image_scale == "middle") {
          image_scale = "point";
          var imgs = svg.selectAll("image");
          imgs.remove();
          var points = svg.selectAll("circle").data(mapped).enter();
          points.append("circle")
            .attr("cx", function(d) { return xScale(d.x);})
            .attr("cy", function(d) { return yScale(d.y);})
            .style("fill", function(d) { return "black";})
            .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;})
            .on("mouseover", function(d) {
              tooltip.transition()
                .duration(200)
                .style("opacity", .8);
              tooltip.html(
                dat.xlabel + " : " + d.x + "<br/>" +
                dat.ylabel + " : " + d.y + "<br/>" +
                "ID: " + d.psid + "<br />" +
                '<img src="' + d.path + '" width="300px" />');
            })
            .on("mousemove", function() {
              tooltip
                .style("top", (d3.event.pageY) + "px")
                .style("left", (d3.event.pageX+10) + "px");
            })
            .on("mouseout", function() {
              tooltip.transition()
                .duration(300)
                .style("opacity", 0);
            })
            .on("dblclick", function(d) {
              window.open(parameter_set_base_url + d.psid, '_blank');
            });
        }
        else if (image_scale == "large") {
          image_scale = "middle";
          var imgs = svg.selectAll("image");
          imgs.attr("width", width/10)
              .attr("height", height/10);
        }
      });
      description.append("br");
      description.append("a").text("show large image").on("click", function() {
        if(image_scale == "point") {
          image_scale = "middle";
          var imgs = svg.selectAll("circle");
          imgs.remove();
          var imgs = svg.selectAll("image").data(mapped).enter();
          imgs.append("svg:image")
            .attr("x", function(d) { return xScale(d.x);})
            .attr("y", function(d) { return yScale(d.y);})
            .attr("xlink:href", function(d) {return d.path})
            .attr("width", width/10)
            .attr("height", height/10)
            .on("mouseover", function(d) {
              tooltip.transition()
                .duration(200)
                .style("opacity", .8);
              tooltip.html(
                dat.xlabel + " : " + d.x + "<br/>" +
                dat.ylabel + " : " + d.y + "<br/>" +
                "ID: " + d.psid + "<br />" +
                '<img src="' + d.path + '" width="300px" />');
            })
            .on("mousemove", function() {
              tooltip
                .style("top", (d3.event.pageY) + "px")
                .style("left", (d3.event.pageX+10) + "px");
            })
            .on("mouseout", function() {
              tooltip.transition()
                .duration(300)
                .style("opacity", 0);
            })
            .on("dblclick", function(d) {
              window.open(parameter_set_base_url + d.psid, '_blank');
            });
        }
        else if(image_scale == "middle") {
          image_scale = "large";
          var imgs = svg.selectAll("image");
          imgs.attr("width", width/5)
              .attr("height", height/5);
        }
      });

      description.append("br");
      description.append("a").text("delete plot").on("click", function() {
        row.remove();
      });
    }
    add_description();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    row.remove();
  });
}
