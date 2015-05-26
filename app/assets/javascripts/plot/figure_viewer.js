function FigureViewer() {
  ScatterPlot.call(this);// call constructor of ScatterPlot
}

FigureViewer.prototype = Object.create(ScatterPlot.prototype);// ScatterPlot is sub class of Plot
FigureViewer.prototype.constructor = FigureViewer;// override constructor
FigureViewer.prototype.on_xaxis_brush_change = null;
FigureViewer.prototype.on_yaxis_brush_change = null;
FigureViewer.prototype.xaxis_original_domain = null;
FigureViewer.prototype.yaxis_original_domain = null;
FigureViewer.prototype.margin = {top: 10+92, right: 100+112, bottom: 100, left: 120};// override margin
FigureViewer.prototype.figure_size = "point";

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
    this.IsLog[0] = false;
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
    this.IsLog[0] = true;
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
    this.IsLog[1] = false;
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
    this.IsLog[1] = true;
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
          .style("opacity", 1.0);
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
  if(xdomain[0] != xdomain[1]) {
    x_figure_scale*=(plot.xaxis_original_domain[1] - plot.xaxis_original_domain[0])/(xdomain[1] - xdomain[0]);
  }
  if(ydomain[0] != ydomain[1]) {
    y_figure_scale*=(plot.yaxis_original_domain[1] - plot.yaxis_original_domain[0])/(ydomain[1] - ydomain[0]);
  }
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
    if(plot.data.irrelevants.length > 0) {
      dl.append("dt").text("Irrevant keys");
      dl.append("dd").text( plot.data.irrelevants.join(',') );
    }
    dl.append("dt").text("URL");
    dl.append("input")
      .attr('class', 'form-control input-sm')
      .attr({"type": "text", "readonly": "readonly", "onClick": "this.select(); "})
      .attr('value', plot.data.plot_url );
  }
  add_label_table();

  function add_tools() {
    var actions = plot.description.append("div").attr('class', 'btn-group');
    actions.append("a")
      .attr({"class": "btn btn-primary btn-sm dropdown-toggle", "data-toggle": "dropdown", "href": "#"})
      .text("Action")
      .append("span").attr("class", "caret");
    var list = actions.append("ul").attr('class', 'dropdown-menu');
    list.append("li").append("a").attr({target: "_blank", href: plot.url}).text("show data in json");
    list.append("li").append("a").text("show smaller image").style('cursor','pointer').on("click", function() {
      if(plot.figure_size == "small") {
        plot.UpdatePlot("point");
      }
      else if(plot.figure_size == "large") {
        plot.UpdatePlot("small");
      }
    });
    list.append("li").append("a").text("show larger image").style('cursor','pointer').on("click", function() {
      if(plot.figure_size == "point") {
        plot.UpdatePlot("small");
      }
      else if(plot.figure_size == "small") {
        plot.UpdatePlot("large");
      }
    });
    list.append("li").append("a").text("delete plot")
      .style("cursor", "pointer")
      .on("click", function() {
        plot.Destructor();
      });
    plot.description.append("div").style("padding-bottom", "50px");

    var log_check_box = plot.description.append("div").attr("class", "checkbox");
    var check_box_x_label = log_check_box.append("label").attr("id", "x_log_check");
    check_box_x_label.html('<input type="checkbox"> log scale on x axis');
    //d3.select gets the first element. This selection is available only when new svg will appear at the above of the old svg.
    d3.select('label#x_log_check input').on("change", function() {
      reset_brush(this.checked ? "log" : "linear", plot.IsLog[1] ? "log" : "linear");
    });
    log_check_box.append("br");

    var check_box_y_label = log_check_box.append("label").attr("id", "y_log_check");
    check_box_y_label.html('<input type="checkbox"> log scale on y axis');
    //d3.select gets the first element. This selection is available only when new svg will appear at the above of the old svg.
    d3.select('label#y_log_check input').on("change", function() {
      reset_brush(plot.IsLog[0] ? "log" : "linear", this.checked ? "log" : "linear");
    });

    plot.description.append("br");
    var control_plot = plot.description.append("div").style("margin-top", "10px");
    function add_brush() {
      var selector = (plot.figure_size == "point") ? "g#point-group" : "g#figure-group";
      var clone = plot.main_group.select(selector).node().cloneNode(true);
      control_plot.append("svg")
        .attr("width","210")
        .attr("height","155")
        .attr("viewBox","0 0 574 473")
        .node().appendChild(clone);

      var x = plot.IsLog[0] ? d3.scale.log() : d3.scale.linear();
      x.range([0, plot.width]);
      x.domain(plot.xScale.domain());
      var x_min = x.domain()[0];
      var x_max = x.domain()[1];
      plot.xaxis_original_domain = x.domain().concat();

      var y = plot.IsLog[1] ? d3.scale.log() : d3.scale.linear();
      y.range([plot.height, 0]);
      y.domain(plot.yScale.domain());
      var y_min = y.domain()[0];
      var y_max = y.domain()[1];
      plot.yaxis_original_domain = y.domain().concat();

      var brush = d3.svg.brush()
        .x(x)
        .y(y)
        .on("brush", brushed);

      var cloned_main_group = d3.select(clone)
        .attr("transform", "translate(5,5)");
      var line_shape = "M0,0V" + plot.height + "H" + plot.width;
      cloned_main_group.append("path").attr("d", line_shape)
        .style({
          "fill": "none",
          "stroke": "#000",
          "shape-rendering": "crispEdges"
        });

      cloned_main_group.append("g")
        .attr("class", "brush")
        .call(brush)
        .selectAll("rect")
        .style({"stroke": "orange", "stroke-width": 4, "fill-opacity": 0.125, "shape-rendering": "crispEdges"});

      function brushed() {
        var domain = brush.empty() ? [[x_min,y_min],[x_max, y_max]] : brush.extent();
        plot.SetXDomain(domain[0][0], domain[1][0]);
        plot.SetYDomain(domain[0][1], domain[1][1]);
        plot.UpdatePlot(plot.figure_size);
        plot.UpdateAxis();
      }
    }
    add_brush();

    function reset_brush (x_linear_log, y_linear_log) {
      plot.SetXScale(x_linear_log); // reset xScale domain to draw non expanded plot
      plot.SetYScale(y_linear_log); // reset xScale domain to draw non expanded plot
      var size = plot.figure_size;
      plot.UpdatePlot("point");  // point plot is drawn for brush
      while (control_plot.node().firstChild) {
        control_plot.node().removeChild(control_plot.node().firstChild);
      }
      add_brush();
      plot.UpdatePlot(size);
    }
  }
  add_tools();

};

FigureViewer.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
  this.UpdatePlot("small");
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

