function FigureViewer() {
  ScatterPlot.call(this);// call constructor of ScatterPlot
}

FigureViewer.prototype = Object.create(ScatterPlot.prototype);// ScatterPlot is sub class of Plot
FigureViewer.prototype.constructor = FigureViewer;// override constructor
FigureViewer.prototype.on_xaxis_brush_change = null;
FigureViewer.prototype.on_yaxis_brush_change = null;
FigureViewer.prototype.margin = {top: 10+92, right: 100+112, bottom: 100, left: 120};// override margin
FigureViewer.prototype.figure_size = "small";

FigureViewer.prototype.Init = function(data, url, parameter_set_base_url, current_ps_id) {
  Plot.prototype.Init.call(this, data, url, parameter_set_base_url, current_ps_id);
  d3.select("#clip rect")
    .attr("y", -5-92)
    .attr("width", this.width+10+112)
    .attr("height", this.height+10+92);
};

FigureViewer.prototype.SetXScale = function(xscale) {
  var scale = null, min, max;
  switch(xscale) {
  case "linear":
    scale = d3.scale.linear().range([0, this.width]);
    min = d3.min( this.data.data, function(d) { return d[0];});
    max = d3.max( this.data.data, function(d) { return d[0];});
    scale.domain([
      min,
      max
    ]).nice();
    break;
  case "log":
    var data_in_logscale = this.data.data.filter(function(element) {
      return element[0] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([0, this.width]);
    min = d3.min( data_in_logscale, function(d) { return d[0];});
    max = d3.max( data_in_logscale, function(d) { return d[0];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    break;
  }
  this.xScale = scale;
  this.xAxis.scale(this.xScale);
};

FigureViewer.prototype.SetYScale = function(yscale) {
  var scale = null, min, max;
  switch(yscale) {
  case "linear":
    scale = d3.scale.linear().range([this.height, 0]);
    min = d3.min( this.data.data, function(d) { return d[1];});
    max = d3.max( this.data.data, function(d) { return d[1];});
    scale.domain([
      min,
      max
    ]).nice();
    break;
  case "log":
    var data_in_logscale = this.data.data.filter(function(element) {
      return element[0] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([this.height, 0]);
    min = d3.min( data_in_logscale, function(d) { return d[1];});
    max = d3.max( data_in_logscale, function(d) { return d[1];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    break;
  }
  this.yScale = scale;
  this.yAxis.scale(this.yScale);
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
  switch(this.figure_size) {
  case "point":
    this.figure_size = new_size;
    if(new_size == "point") {
      this.UpdatePointPlot();
    } else {
      this.main_group.select("g#point-group").remove();
      this.AddPlot();
    }
    break;
  case "small":
  case "large":
    this.figure_size = new_size;
    if(new_size == "point") {
      this.main_group.select("g#figure-group").remove();
      this.AddPlot();
    } else {
      this.UpdateFigurePlot();
    }
    break;
  }

  this.UpdateAxis();
};

FigureViewer.prototype.AddFigurePlot = function() {
  var plot = this;

  function add_figure_group() {
    var tooltip = d3.select("#plot-tooltip");
    var mapped = plot.data.data.map(function(v) {
      return { x: v[0], y: v[1], path:v[2], psid: v[3] };
    });
    var figure_group = plot.main_group.append("g")
      .attr("id", "figure-group");
    var figure = figure_group.selectAll("image")
      .data(mapped).enter();
    figure.append("svg:image")
      .attr("clip-path", "url(#clip)")
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
        window.open(plot.parameter_set_base_url + d.psid, '_blank');
      });
  }
  add_figure_group();
  this.UpdateFigurePlot();
};

FigureViewer.prototype.UpdateFigurePlot = function() {
  var plot = this;
  var x_figure_scale = (this.figure_size == "small") ? 0.1 : 0.2;
  var y_figure_scale = (this.figure_size == "small") ? 0.1 : 0.2;
  var xdomain = plot.xScale.domain();
  var ydomain = plot.yScale.domain();
  var xdomainbottom;
  if(plot.xScaleBottom) {
    xdomainbottom = plot.xScaleBottom.domain();
  } else {
    xdomainbottom = plot.xScale.domain();
  }
  var ydomainleft;
  if(plot.yScaleLeft) {
    ydomainleft = plot.yScaleLeft.domain();
  } else {
    ydomainleft = plot.yScale.domain();
  }
  x_figure_scale*=(xdomainbottom[1] - xdomainbottom[0])/(xdomain[1] - xdomain[0]);
  y_figure_scale*=(ydomainleft[1] - ydomainleft[0])/(ydomain[1] - ydomain[0]);
  function update_figure_plot() {
    var figure_group = plot.main_group.select("g#figure-group");
    figure_group.selectAll("image")
      .attr("x", function(d) { return plot.xScale(d.x);})
      .attr("y", function(d) { return plot.yScale(d.y) - plot.height*y_figure_scale;})
      .attr("xlink:href", function(d) { return d.path; })
      .attr("width", plot.width*x_figure_scale)
      .attr("height", plot.height*y_figure_scale);
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
    var point_group = plot.main_group.append("g")
      .attr("id", "point-group");
    var point = point_group.selectAll("circle")
      .data(mapped).enter();
    point.append("circle")
      .attr("clip-path", "url(#clip)")
      .style("fill", function() { return "black";})
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
        window.open(plot.parameter_set_base_url + d.psid, '_blank');
      });
  }
  add_point_group();

  this.UpdatePointPlot();
};

FigureViewer.prototype.UpdatePointPlot = function() {
  var plot = this;

  function update_point_group() {
    var point_group = plot.main_group.select("g#point-group");
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
    plot.description.append("a").text("show smaller image").style('cursor','pointer').on("click", function() {
      if(plot.figure_size == "small") {
        plot.UpdatePlot("point");
      }
      else if(plot.figure_size == "large") {
        plot.UpdatePlot("small");
      }
    });
    plot.description.append("br");
    plot.description.append("a").text("show larger image").style('cursor','pointer').on("click", function() {
      if(plot.figure_size == "point") {
        plot.UpdatePlot("small");
      }
      else if(plot.figure_size == "small") {
        plot.UpdatePlot("large");
      }
    });
    plot.description.append("br");

    plot.description.append("a").text("delete plot").style('cursor','pointer').on("click", function() {
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
      plot.UpdatePlot(plot.figure_size);
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
      plot.UpdatePlot(plot.figure_size);
    });
    plot.description.append("span").html("log scale on y axis");

    function add_xaxis_controller() {
      var height_bottom = plot.height + plot.margin.bottom - 40;
      FigureViewer.prototype.xScaleBottom = null;
      var xAxisBottom = d3.svg.axis().orient("bottom");
      var scale = null, min, max;
      scale = d3.scale.linear().range([0, plot.width]);
      min = d3.min( plot.data.data, function(d) { return d[0];});
      max = d3.max( plot.data.data, function(d) { return d[0];});
      scale.domain([
          min,
          max
          ]).nice();
      plot.xScaleBottom = scale;
      xAxisBottom.scale(plot.xScaleBottom);

      plot.main_group.append("g")
        .attr("class", "x axis bottom")
        .attr("transform", "translate(0," + height_bottom + ")")
        .call(xAxisBottom);

      plot.on_xaxis_brush_change = function() {
        var domain = brush.empty() ? plot.xScaleBottom.domain() : brush.extent();
        plot.SetXDomain(domain[0], domain[1]);
        plot.UpdatePlot(plot.figure_size);
        plot.main_group.select(".x.axis").call(plot.xAxis);
      };

      var brush = d3.svg.brush()
        .x(plot.xScaleBottom)
        .on("brush", plot.on_xaxis_brush_change);

      plot.main_group.append("g")
        .attr("class", "x brush")
        .call(brush)
        .selectAll("rect")
        .attr("y", height_bottom-8)
        .style({stroke: "orange", "fill-opacity": 0.125, "shape-rendering": "crispEdges"})
        .attr("height", 16);
    }
    add_xaxis_controller();

    function add_yaxis_controller() {
      var width_left = -plot.margin.left + 50;
      FigureViewer.prototype.YScaleLeft = null;
      var yAxisLeft = d3.svg.axis().orient("left");
      var scale = null, min, max;
      scale = d3.scale.linear().range([plot.height, 0]);
      min = d3.min( plot.data.data, function(d) { return d[1];});
      max = d3.max( plot.data.data, function(d) { return d[1];});
      scale.domain([
          min,
          max
          ]).nice();
      plot.yScaleLeft = scale;
      yAxisLeft.scale(plot.yScaleLeft);

      plot.main_group.append("g")
        .attr("class", "y axis left")
        .attr("transform", "translate(" + width_left + ",0)")
        .call(yAxisLeft);

      plot.on_yaxis_brush_change = function() {
        var domain = brush.empty() ? plot.yScaleLeft.domain() : brush.extent();
        plot.SetYDomain(domain[0], domain[1]);
        plot.UpdatePlot(plot.figure_size);
        plot.main_group.select(".y.axis").call(plot.yAxis);
      };

      var brush = d3.svg.brush()
        .y(plot.yScaleLeft)
        .on("brush", plot.on_yaxis_brush_change);

      plot.main_group.append("g")
        .attr("class", "y brush")
        .call(brush)
        .selectAll("rect")
        .attr("x", width_left-8)
        .style({stroke: "orange", "fill-opacity": 0.125, "shape-rendering": "crispEdges"})
        .attr("width", 16);
    }
    add_yaxis_controller();
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
  var progress = show_loading_spin_arc(plot.main_group, plot.width, plot.height);

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
}

