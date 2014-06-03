function Plot() {
  this.row = d3.select("#plot").insert("div","div").attr("class", "row");
  this.plot_region = this.row.append("div").attr("class", "span8");
  this.description = this.row.append("div").attr("class", "span4");
  this.svg = this.plot_region.insert("svg")
    .attr({
      "width": this.width + this.margin.left + this.margin.right,
      "height": this.height + this.margin.top + this.margin.bottom
    })
    .append("g")
      .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");
}

Plot.prototype.margin = {top: 10, right: 100, bottom: 100, left: 100};
Plot.prototype.width = 560;
Plot.prototype.height = 460;
Plot.prototype.xScale = null;
Plot.prototype.yScale = null;
Plot.prototype.xAxis = null;
Plot.prototype.yAxis = null;
Plot.prototype.data = null;
Plot.prototype.url = null;
Plot.prototype.current_ps_id = null;
Plot.prototype.parameter_set_base_url = null;

Plot.prototype.Init = function(data, url, parameter_set_base_url, current_ps_id) {
  this.data = data;
  this.url = url;
  this.parameter_set_base_url = parameter_set_base_url;
  this.current_ps_id = current_ps_id;

  this.SetXScale("linear");
  this.SetYScale("linear");
  this.xAxis = d3.svg.axis().scale(this.xScale).orient("bottom");
  this.yAxis = d3.svg.axis().scale(this.yScale).orient("left");
};

Plot.prototype.Destructor = function() { this.row.remove(); };

Plot.prototype.AddAxis = function() {
  // X-Axis
  this.svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + this.height + ")")
    .append("text")
      .style("text-anchor", "middle")
      .attr("x", this.width / 2.0)
      .attr("y", 50.0)
      .text(this.data.xlabel);

  // Y-Axis
  this.svg.append("g")
    .attr("class", "y axis")
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -this.height/2)
      .attr("y", -50.0)
      .style("text-anchor", "middle")
      .text(this.data.ylabel);

  this.UpdateAxis();
};

Plot.prototype.UpdateAxis = function() {
  this.svg.select(".x.axis").call(this.xAxis);
  this.svg.select(".y.axis").call(this.yAxis);
}

function LinePlot() {
  Plot.call(this);// call constructor of Plot
}

LinePlot.prototype = Object.create(Plot.prototype);// LinePlot is sub class of Plot
LinePlot.prototype.constructor = LinePlot;// override constructor
LinePlot.prototype.data = null;

LinePlot.prototype.SetXScale = function(xscale) {
  var scale = null;
  switch(xscale) {
    case "linear":
      scale = d3.scale.linear().range([0, this.width]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})}),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([0, this.width]);
      var min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
    default: // undefined
      scale = d3.scale.linear().range([0, this.width]);
      console.log(xscale + "is not defined as scale. Set linear scale for x-axis.");
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})}),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
  }
  this.xScale = scale;
};

LinePlot.prototype.SetYScale = function(yscale) {
  var scale = null;
  switch(yscale) {
    case "linear":
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];}) }),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];}) })
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([this.height, 0]);
      var min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];})})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];})})
      ]).nice();
      break;
    default: // undefined
      console.log(scale + "is not defined as scale. Set linear scale for y-axis.");
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];}) }),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];}) })
      ]).nice();
      break;
  }
  this.yScale = scale;
};

LinePlot.prototype.AddPlot = function() {
  var plot = this;
  var colorScale = d3.scale.category10();

  // group for each series
  var series = this.svg
    .selectAll(".series")
    .data(this.data.data)
    .enter().append("g")
      .attr("class", "series");
  series.append("path")
    .attr("class", "line")
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
          series_index: i, series_value: plot.data.series_values[i], psid: v[3]
        };
      });
    }).enter();
  point.append("circle")
    .style("fill", function(d) { return colorScale(d.series_index);})
    .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
    .on("mouseover", function(d) {
      tooltip.transition()
        .duration(200)
        .style("opacity", .8);
      tooltip.html(
        plot.data.xlabel + " : " + d.x + "<br/>" +
        plot.data.ylabel + " : " + Math.round(d.y*1000000)/1000000 +
        " (" + Math.round(d.yerror*1000000)/1000000 + ")<br/>" +
        (plot.data.series ? (plot.data.series + " : " + d.series_value + "<br/>") : "") +
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
      window.open(plot.parameter_set_base_url + d.psid, '_blank');
    });

  // draw error bar
  point.insert("line", "circle")
    .attr("class", "line yerror bar");
  point.insert("line", "circle")
    .attr("class", "line yerror top");
  point.insert("line", "circle")
    .attr("class", "line yerror bottom");

  // draw legend
  var legend = this.svg.append("g")
    .attr("class", "legend")
    .attr("transform", "translate(" + this.width + "," + 20 + ")");
  var legendItem = legend.selectAll("g")
    .data(this.data.series_values)
    .enter().append("g")
    .attr("class", "legend-item")
    .attr("transform", function(d,i) {
      return "translate(10," + (i*20) + ")";
    });

  // draw legend title
  this.svg.append("text")
    .attr({
      x: this.width,
      y: 0,
      dx: ".8em",
      dy: ".8em"
    })
    .text(this.data.series);
  legendItem.append("rect")
    .attr("width", 15)
    .attr("height", 15)
    .style("fill", function(d,i) { return colorScale(i);});
  legendItem.append("text")
    .attr("x", 20)
    .attr("y", 7.5)
    .attr("dy", "0.3em")
    .text( function(d,i) { return d; });

  this.UpdatePlot();
};

LinePlot.prototype.UpdatePlot = function() {
  var plot = this;
  var colorScale = d3.scale.category10();
  var line = d3.svg.line()
    .x( function(d) { return plot.xScale(d[0]);} )
    .y( function(d) { return plot.yScale(d[1]);} );
  var tooltip = d3.select("#plot-tooltip");

  // draw line path
  this.svg.selectAll("path").attr("d", function(d) { return line(d);});

  // draw data point
  this.svg.selectAll("circle")
    .attr("cx", function(d) { return plot.xScale(d.x);})
    .attr("cy", function(d) { return plot.yScale(d.y);});

  // draw error bar
  this.svg.selectAll(".line.yerror.bar")
    .filter(function(d) { return d.yerror;})
    .attr({
      x1: function(d) { return plot.xScale(d.x);},
      x2: function(d) { return plot.xScale(d.x);},
      y1: function(d) { return plot.yScale(d.y - d.yerror);},
      y2: function(d) { return plot.yScale(d.y + d.yerror);},
      stroke: function(d) { return colorScale(d.series_index); }
    });
  this.svg.selectAll(".line.yerror.top")
    .filter(function(d) { return d.yerror;})
    .attr({
      x1: function(d) { return plot.xScale(d.x) - 3;},
      x2: function(d) { return plot.xScale(d.x) + 3;},
      y1: function(d) { return plot.yScale(d.y - d.yerror);},
      y2: function(d) { return plot.yScale(d.y - d.yerror);},
      stroke: function(d) { return colorScale(d.series_index); }
    });
  this.svg.selectAll(".line.yerror.bottom")
    .filter(function(d) { return d.yerror;})
    .attr({
      x1: function(d) { return plot.xScale(d.x) - 3;},
      x2: function(d) { return plot.xScale(d.x) + 3;},
      y1: function(d) { return plot.yScale(d.y + d.yerror);},
      y2: function(d) { return plot.yScale(d.y + d.yerror);},
      stroke: function(d) { return colorScale(d.series_index); }
    });
};

LinePlot.prototype.AddDescription = function() {
  var plot = this;

  // description for the specification of the plot
  var dl = this.description.append("dl");
  dl.append("dt").text("X-Axis");
  dl.append("dd").text(this.data.xlabel);
  dl.append("dt").text("Y-Axis");
  dl.append("dd").text(this.data.ylabel);
  if(this.data.series) {
    dl.append("dt").text("Series");
    dl.append("dd").text(this.data.series);
  }
  this.description.append("a").attr({target: "_blank", href: this.url}).text("show data in json");
  this.description.append("br");
  plt_url = this.url.replace(/\.json/, '.plt')
  this.description.append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
  this.description.append("br");
  this.description.append("a").text("delete plot").on("click", function() {
    plot.Destructor();
  });
  this.description.append("br");

  this.description.append("br").style("line-height", "400%");
  this.description.append("input").attr("type", "checkbox").on("change", function() {
    var new_scale;
    if(this.checked) {
      new_scale = "log";
    } else {
      new_scale = "linear";
    }
    plot.SetXScale(new_scale);
    plot.xAxis.scale(plot.xScale);
    plot.UpdatePlot();
    plot.UpdateAxis();
  });
  this.description.append("span").html("log scale on x axis");
  this.description.append("br");

  this.description.append("input").attr("type", "checkbox").on("change", function() {
    var new_scale;
    if(this.checked) {
      new_scale = "log";
    } else {
      new_scale = "linear";
    }
    plot.SetYScale(new_scale);
    plot.yAxis.scale(plot.yScale);
    plot.UpdatePlot();
    plot.UpdateAxis();
  });
  this.description.append("span").html("log scale on y axis");
};

LinePlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_line_plot(url, parameter_set_base_url, current_ps_id) {
  var plot = new LinePlot();
  var progress = show_loading_spin_arc(plot.svg, plot.width, plot.height);
  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.Init(dat, url, parameter_set_base_url, current_ps_id);
    plot.Draw();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
};

function ScatterPlot() {
  Plot.call(this);// call constructor of Plot
}

ScatterPlot.prototype = Object.create(Plot.prototype);// ScatterPlot is sub class of Plot
ScatterPlot.prototype.constructor = ScatterPlot;// override constructor
ScatterPlot.prototype.data = null;

ScatterPlot.prototype.SetXScale = function(xscale) {
  var plot = this;
  var scale = null;
  switch(xscale) {
    case "linear":
      scale = d3.scale.linear().range([0, this.width]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0][plot.data.xlabel];}),
        d3.max( this.data.data, function(d) { return d[0][plot.data.xlabel];})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([0, this.width]);
      var min = d3.min( this.data.data, function(d) { return d[0][plot.data.xlabel];})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(d) { return d[0][plot.data.xlabel];})
      ]).nice();
      break;
    default: // undefined
      scale = d3.scale.linear().range([0, this.width]);
      console.log(xscale + "is not defined as scale. Set linear scale for x-axis.");
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0][plot.data.xlabel];}),
        d3.max( this.data.data, function(d) { return d[0][plot.data.xlabel];})
      ]).nice();
      break;
  }
  this.xScale = scale;
};

ScatterPlot.prototype.SetYScale = function(yscale) {
  var plot = this;
  var scale = null;
  switch(yscale) {
    case "linear":
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0][plot.data.ylabel];}),
        d3.max( this.data.data, function(d) { return d[0][plot.data.ylabel];})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([this.height, 0]);
      var min = d3.min( this.data.data, function(d) { return d[0][plot.data.ylabel];})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(d) { return d[0][plot.data.ylabel];})
      ]).nice();
      break;
    default: // undefined
      console.log(scale + "is not defined as scale. Set linear scale for y-axis.");
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0][plot.data.ylabel];}),
        d3.max( this.data.data, function(d) { return d[0][plot.data.ylabel];})
      ]).nice();
      break;
  }
  this.yScale = scale;
};

ScatterPlot.prototype.AddPlot = function() {
  var plot = this;

  var result_min_val = d3.min( this.data.data, function(d) { return d[1];});
  var result_max_val = d3.max( this.data.data, function(d) { return d[1];});
  var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
  var colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
  colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
  colorScalePoint.domain( colorScale.domain() ).nice();

  function add_color_map_group() {
    var color_map_group = plot.svg.append("g")
      .attr({
        "transform": "translate(" + plot.width + "," + plot.margin.top + ")",
        "id": "color-map-group"
      });
    var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(colorScale.range());
    color_map_group.append("text")
      .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
      .style("text-anchor", "begin")
      .text("Result");
    color_map_group.selectAll("rect")
      .data([1.0, 0.8, 0.6, 0.4, 0.2, 0.0])
      .enter().append("rect")
      .attr({
        x: 10.0,
        y: function(d,i) { return i * 20.0 + 20.0; },
        width: 19,
        height: 19,
        fill: function(d) { return scale(d); }
      });
    color_map_group.append("text")
      .attr({x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( colorScale.domain()[2] );
    color_map_group.append("text")
      .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( colorScale.domain()[0] );
  }
  add_color_map_group();

  function add_voronoi_group() {
    var voronoi_group = plot.svg.append("g")
      .attr("id", "voronoi-group");
  }
  add_voronoi_group();

  function add_point_group() {
    var tooltip = d3.select("#plot-tooltip");
    var mapped = plot.data.data.map(function(v) {
      return {
        x: v[0][plot.data.xlabel], y: v[0][plot.data.ylabel],
        average: v[1], error: v[2], psid: v[3]
      };
    });
    var point_group = plot.svg.append("g")
      .attr("id", "point-group");
    var point = point_group.selectAll("circle")
      .data(mapped).enter();
    point.append("circle")
      .style("fill", function(d) { return colorScalePoint(d.average);})
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", .8);
        tooltip.html(
          plot.data.xlabel + " : " + d.x + "<br/>" +
          plot.data.ylabel + " : " + d.y + "<br/>" +
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
        window.open(plot.parameter_set_base_url + d.psid, '_blank');
      });
  }
  add_point_group();

  this.UpdatePlot();
};

ScatterPlot.prototype.UpdatePlot = function() {
  var plot = this;

  function update_voronoi_group() {
    var result_min_val = d3.min( plot.data.data, function(d) { return d[1];});
    var result_max_val = d3.max( plot.data.data, function(d) { return d[1];});
    var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
    colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
    var voronoi_group = plot.svg.select("g#voronoi-group");
    var voronoi = d3.geom.voronoi()
      .clipExtent([[0, 0], [plot.width, plot.height]]);
    var vertices = plot.data.data.map(function(v) {
      return [
        plot.xScale(v[0][plot.data.xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
        plot.yScale(v[0][plot.data.ylabel]) + Math.random() * 1.0 - 0.5
      ];
    });
    function draw_voronoi_heat_map() {
      // add noise to coordinates of vertices in order to prevent hang-up.
      // hanging-up sometimes happen when duplicated points are included.
      var path = voronoi_group.selectAll("path")
        .data(voronoi(vertices));
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(plot.data.data[i][1]);})
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .style("fill-opacity", 0.7)
        .style("stroke", "none");
    }
    try {
      voronoi_group.selectAll("path").remove();
      draw_voronoi_heat_map();
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }
  }
  update_voronoi_group();

  function update_point_group() {
    var point_group = plot.svg.select("g#point-group");
    point_group.selectAll("circle")
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});
  }
  update_point_group();
};

ScatterPlot.prototype.AddDescription = function() {
  var plot = this;

  // description for the specification of the plot
  var dl = this.description.append("dl");
  dl.append("dt").text("X-Axis");
  dl.append("dd").text(this.data.xlabel);
  dl.append("dt").text("Y-Axis");
  dl.append("dd").text(this.data.ylabel);
  dl.append("dt").text("Result");
  dl.append("dd").text(this.data.result);
  this.description.append("a").attr({target: "_blank", href: this.url}).text("show data in json");
  this.description.append("br");
  this.description.append("a").text("delete plot").on("click", function() {
    plot.Destructor();
  });

  this.description.append("br");
  this.description.append("br").style("line-height", "400%");
  this.description.append("input").attr("type", "checkbox").on("change", function() {
    var new_scale;
    if(this.checked) {
      new_scale = "log";
    } else {
      new_scale = "linear";
    }
    plot.SetXScale(new_scale);
    plot.xAxis.scale(plot.xScale);
    plot.UpdatePlot();
    plot.UpdateAxis();
  });
  this.description.append("span").html("log scale on x axis");
  this.description.append("br");

  this.description.append("input").attr("type", "checkbox").on("change", function() {
    var new_scale;
    if(this.checked) {
      new_scale = "log";
    } else {
      new_scale = "linear";
    }
    plot.SetYScale(new_scale);
    plot.yAxis.scale(plot.yScale);
    plot.UpdatePlot();
    plot.UpdateAxis();
  });
  this.description.append("span").html("log scale on y axis");
};

ScatterPlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_scatter_plot(url, parameter_set_base_url, current_ps_id) {
  var plot = new ScatterPlot();
  var progress = show_loading_spin_arc(plot.svg, plot.width, plot.height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.Init(dat, url, parameter_set_base_url, current_ps_id);
    plot.Draw();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
};

function FigureViewer() {
  ScatterPlot.call(this);// call constructor of ScatterPlot
}

FigureViewer.prototype = Object.create(ScatterPlot.prototype);// ScatterPlot is sub class of Plot
FigureViewer.prototype.constructor = FigureViewer;// override constructor
FigureViewer.prototype.figure_size = "small";
FigureViewer.prototype.margin = {top: 10+92, right: 100+112, bottom: 100, left: 100};

FigureViewer.prototype.SetXScale = function(xscale) {
  var plot = this;
  var scale = null;
  switch(xscale) {
    case "linear":
      scale = d3.scale.linear().range([0, this.width]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0];}),
        d3.max( this.data.data, function(d) { return d[0];})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([0, this.width]);
      var min = d3.min( this.data.data, function(d) { return d[0];});
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(d) { return d[0];})
      ]).nice();
      break;
    default: // undefined
      scale = d3.scale.linear().range([0, this.width]);
      console.log(xscale + "is not defined as scale. Set linear scale for x-axis.");
      scale.domain([
        d3.min( this.data.data, function(d) { return d[0];}),
        d3.max( this.data.data, function(d) { return d[0];})
      ]).nice();
      break;
  }
  this.xScale = scale;
};

FigureViewer.prototype.SetYScale = function(yscale) {
  var plot = this;
  var scale = null;
  switch(yscale) {
    case "linear":
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[1];}),
        d3.max( this.data.data, function(d) { return d[1];})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([this.height, 0]);
      var min = d3.min( this.data.data, function(d) { return d[1];})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(d) { return d[1];})
      ]).nice();
      break;
    default: // undefined
      console.log(scale + "is not defined as scale. Set linear scale for y-axis.");
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(d) { return d[1];}),
        d3.max( this.data.data, function(d) { return d[1];})
      ]).nice();
      break;
  }
  this.yScale = scale;
};
FigureViewer.prototype.AddPlot = function() {
  switch(this.figure_size) {
    case "point":
      this.AddPointPlot();
      break;
    case "small":
    case "large":
      this.AddFigurePlot();
      break;
  }
};

delete FigureViewer.prototype.UpdatePlot; // delete ScatterPlot.UpdatePlot() from FigureViewer
FigureViewer.prototype.UpdatePlot = function(new_size) {
  switch(new_size) {
    case "point":
      if(new_size == this.figuer_size) {
        this.UpdatePointPlot();
      } else {
        this.figure_size = new_size;
        this.svg.select("g#figure-group").remove();
        this.AddPlot();
      }
      break;
    case "small":
    case "large":
      if(new_size == this.figuer_size) {
        this.UpdateFigurePlot();
      } else {
        this.figure_size = new_size;
        this.svg.select("g#point-group").remove();
        this.AddPlot();
      }
      break;
  }
};

FigureViewer.prototype.AddFigurePlot = function() {
  var plot = this;

  function add_figure_group() {
    var tooltip = d3.select("#plot-tooltip");
    var mapped = plot.data.data.map(function(v) {
      return { x: v[0], y: v[1], path:v[2], psid: v[3] };
    });
    var figure_group = plot.svg.append("g")
      .attr("id", "figure-group");
    var figure = figure_group.selectAll("image")
      .data(mapped).enter();
    figure.append("svg:image")
      .attr("xlink:href", function(d) { return d.path; })
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", 0.8);
        tooltip.html(function() {
          var str = plot.data.xlabel + " : " + d.x + "<br/>" +
          plot.data.ylabel + " : " + d.y + "<br/>" +
          "ID: " + d.psid + "<br />";
          if(d.path) {
            str += '<img src="' + d.path + '" width="300px" />';
          } else {
            str += "<br />"+"<br />"+"NO IMAGE"+"<br />"+"<br />";
          }
          return str;
        });
      })
      .on("mousemove", function() {
        tooltip
          .style("top", (d3.event.pageY-300) + "px")
          .style("left", (d3.event.pageX-150) + "px");
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
  add_figure_group();
  this.UpdateFigurePlot();
};

FigureViewer.prototype.UpdateFigurePlot = function() {
  var plot = this;
  var figure_scale = (this.figure_size == "small") ? 0.1 : 0.2;
  function update_figure_plot() {
    var figure_group = plot.svg.select("g#figure-group");
    figure_group.selectAll("image")
      .attr("x", function(d) { return plot.xScale(d.x);})
      .attr("y", function(d) { return plot.yScale(d.y) - plot.height*figure_scale;})
      .attr("xlink:href", function(d) { return d.path; })
      .attr("width", plot.width*figure_scale)
      .attr("height", plot.height*figure_scale);
  }
  update_figure_plot();
};

FigureViewer.prototype.AddPointPlot = function() {
  var plot = this;

  function add_point_group() {
    var tooltip = d3.select("#plot-tooltip");
    var mapped = plot.data.data.map(function(v) {
      return { x: v[0], y: v[1], path:v[2], psid: v[3] };
    });
    var point_group = plot.svg.append("g")
      .attr("id", "point-group");
    var point = point_group.selectAll("circle")
      .data(mapped).enter();
    point.append("circle")
      .style("fill", function(d) { return "black";})
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", 0.8);
          tooltip.html(function() {
            var str = plot.data.xlabel + " : " + d.x + "<br/>" +
            plot.data.ylabel + " : " + d.y + "<br/>" +
            "ID: " + d.psid + "<br />";
            if(d.path) {
              str += '<img src="' + d.path + '" width="300px" />';
            } else {
              str += "<br />"+"<br />"+"NO IMAGE"+"<br />"+"<br />";
            }
            return str;
          });
      })
      .on("mousemove", function() {
        tooltip
          .style("top", (d3.event.pageY-300) + "px")
          .style("left", (d3.event.pageX-150) + "px");
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
  add_point_group();

  this.UpdatePointPlot();
};

FigureViewer.prototype.UpdatePointPlot = function() {
  var plot = this;

  function update_point_group() {
    var point_group = plot.svg.select("g#point-group");
    point_group.selectAll("circle")
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});
  }
  update_point_group();
};

FigureViewer.prototype.AddDescription = function() {
  var plot = this;

  // description for the specification of the plot
  function add_label_table() {
  var dl = plot.description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(plot.data.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(plot.data.ylabel);
    dl.append("dt").text("Result");
    dl.append("dd").text(plot.data.result);
  }
  add_label_table();

  function add_tools() {
    plot.description.append("a").attr({target: "_blank", href: plot.url}).text("show data in json");
    plot.description.append("br");
    plot.description.append("a").text("show smaller image").on("click", function() {
      if(plot.figure_size == "small") {
        plot.UpdatePlot("point");
      }
      else if(plot.figure_size == "large") {
        plot.UpdatePlot("small");
      }
    });
    plot.description.append("br");
    plot.description.append("a").text("show larger image").on("click", function() {
      if(plot.figure_size == "point") {
        plot.UpdatePlot("small");
      }
      else if(plot.figure_size == "small") {
        plot.UpdatePlot("large");
      }
    });
    plot.description.append("br");

    plot.description.append("a").text("delete plot").on("click", function() {
      plot.Destructor();
    });
    plot.description.append("br");

    plot.description.append("br").style("line-height", "400%");
    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
      } else {
        new_scale = "linear";
      }
      plot.SetXScale(new_scale);
      plot.xAxis.scale(plot.xScale);
      plot.UpdatePlot(plot.figure_size);
      plot.UpdateAxis();
    });
    plot.description.append("span").html("log scale on x axis");
    plot.description.append("br");

    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
      } else {
        new_scale = "linear";
      }
      plot.SetYScale(new_scale);
      plot.yAxis.scale(plot.yScale);
      plot.UpdatePlot(plot.figure_size);
      plot.UpdateAxis();
    });
    plot.description.append("span").html("log scale on y axis");
  }
  add_tools();
};

FigureViewer.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_figure_viewer(url, parameter_set_base_url, current_ps_id) {
  var plot = new FigureViewer();
  var progress = show_loading_spin_arc(plot.svg, plot.width, plot.height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.Init(dat, url, parameter_set_base_url, current_ps_id);
    plot.Draw();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
};

