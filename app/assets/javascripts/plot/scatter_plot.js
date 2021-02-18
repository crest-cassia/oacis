function ScatterPlot() {
  Plot.call(this);// call constructor of Plot
  this.colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
  this.colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
}

ScatterPlot.prototype = Object.create(Plot.prototype);// ScatterPlot is sub class of Plot
ScatterPlot.prototype.constructor = ScatterPlot;// override constructor
ScatterPlot.prototype.IsLog = [false, false];   // true if x/y scale is log

ScatterPlot.prototype.SetXScale = function(xscale) {
  const plot = this;
  let scale = null, min, max;
  switch(xscale) {
  case "linear":
    scale = d3.scale.linear().range([0, this.width]);
    min = d3.min( this.data.data, function(r) { return r[0][plot.data.xlabel];});
    max = d3.max( this.data.data, function(r) { return r[0][plot.data.xlabel];});
    scale.domain([
      min,
      max
    ]).nice();
    plot.IsLog[0] = false;
    break;
  case "log":
    const data_in_logscale = this.data.data.filter(function(element, index, array) {
      return element[0][plot.data.xlabel] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([0, this.width]);
    min = d3.min( data_in_logscale, function(r) { return r[0][plot.data.xlabel];});
    max = d3.max( data_in_logscale, function(r) { return r[0][plot.data.xlabel];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    plot.IsLog[0] = true;
    break;
  }
  this.xScale = scale;
  this.xAxis.scale(this.xScale);
};

ScatterPlot.prototype.SetYScale = function(yscale) {
  const plot = this;
  let scale = null, min, max;
  switch(yscale) {
  case "linear":
    scale = d3.scale.linear().range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return r[0][plot.data.ylabel];});
    max = d3.max( this.data.data, function(r) { return r[0][plot.data.ylabel];});
    scale.domain([
      min,
      max
    ]).nice();
    plot.IsLog[1] = false;
    break;
  case "log":
    const data_in_logscale = this.data.data.filter(function(element, index, array) {
      return element[0][plot.data.ylabel] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([this.height, 0]);
    min = d3.min( data_in_logscale, function(r) { return r[0][plot.data.ylabel];});
    max = d3.max( data_in_logscale, function(r) { return r[0][plot.data.ylabel];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    plot.IsLog[1] = true;
    break;
  }
  this.yScale = scale;
  this.yAxis.scale(this.yScale);
};

ScatterPlot.prototype.SetXDomain = function(xmin, xmax) {
  const plot = this;
  if( plot.IsLog[0] ) {
    if( xmin <= 0.0 ) {
      plot.SetXScale("log"); // call this to calculate auto-domain
      xmin = plot.xScale.domain()[0];
      if( xmax <= 0.0 ) {
        xmax = xmin + 0.000001;
      }
    }
  }
  plot.xScale.domain([xmin, xmax]);
};

ScatterPlot.prototype.SetYDomain = function(ymin, ymax) {
  const plot = this;
  if( plot.IsLog[1] ) {
    if( ymin <= 0.0 ) {
      plot.SetYScale("log"); // call this to calculate auto-domain
      ymin = plot.yScale.domain()[0];
      if( ymax <= 0.0 ) {
        ymax = ymin + 0.000001;
      }
    }
  }
  plot.yScale.domain([ymin, ymax]);
};

ScatterPlot.prototype.AddPlot = function() {
  const plot = this;

  function set_color_map_scale() {
    const result_min_val = d3.min( plot.data.data, function(d) { return d[1];});
    const result_max_val = d3.max( plot.data.data, function(d) { return d[1];});
    const niced = d3.scale.linear().domain([result_min_val, result_max_val]).nice().domain();
    plot.colorScale.domain([ niced[0], (niced[0]+niced[1])/2.0, niced[1]]).nice();
    plot.colorScalePoint.domain( plot.colorScale.domain() ).nice();
  }
  set_color_map_scale();

  function add_color_map_group() {
    const color_map = plot.main_group.append("g")
      .attr({
        "transform": "translate(" + plot.width + "," + plot.margin.top + ")",
        "id": "color-map-group"
      });
    const scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(plot.colorScale.range());
    color_map.append("text")
      .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
      .style("text-anchor", "begin")
      .text("Result");
    color_map.selectAll("rect")
      .data([1.0, 0.8, 0.6, 0.5, 0.4, 0.2, 0.0])
      .enter().append("rect")
      .attr({
        x: 10.0,
        y: function(d,i) { return i * 20.0 + 20.0; },
        width: 19,
        height: 19,
        fill: function(d) { return scale(d); }
      });
    color_map.append("text")
      .attr({id:"result-range-max", x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[2] );
    color_map.append("text")
      .attr({id:"result-range-middle", x: 30.0, y: 100.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[1] );
    color_map.append("text")
      .attr({id:"result-range-min", x: 30.0, y: 160.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[0] );
  }
  add_color_map_group();

  const plot_group = plot.main_group.append("g").attr("id", "plot-group");

  function add_voronoi_group() {
    const voronoi_group = plot_group.append("g")
      .attr("id", "voronoi-group");
  }
  add_voronoi_group();

  function add_point_group() {
    const tooltip = d3.select("#plot-tooltip");
    const mapped = plot.data.data.map(function(v) {
      return {
        x: v[0][plot.data.xlabel], y: v[0][plot.data.ylabel],
        average: v[1], error: v[2], psid: v[3]
      };
    });
    const point = plot_group.append("g")
      .attr("id", "point-group");
    point.selectAll("circle")
      .data(mapped)
      .enter()
        .append("circle")
        .attr("clip-path", "url(#clip)")
        .style("fill", function(d) { return plot.colorScalePoint(d.average);})
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", 0.8);
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
  const plot = this;

  function update_color_scale() {
    const scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(plot.colorScale.range());

    plot.main_group.select("#result-range-max")
      .text( plot.colorScale.domain()[2] );
    plot.main_group.select("#result-range-middle")
      .text( plot.colorScale.domain()[1] );
    plot.main_group.select("#result-range-min")
      .text( plot.colorScale.domain()[0] );

    plot.main_group.selectAll("circle")
      .style("fill", function(d) { return plot.colorScalePoint(d.average);});
  }
  update_color_scale();

  function update_voronoi_group() {
    const result_min_val = d3.min( plot.data.data, function(d) { return d[1];});
    const result_max_val = d3.max( plot.data.data, function(d) { return d[1];});
    const voronoi = plot.main_group.select("g#voronoi-group");
    const d3voronoi = d3.geom.voronoi()
      .clipExtent([[0, 0], [plot.width, plot.height]]);
    const filtered_data = plot.data.data.filter(function(v) {
      const x = v[0][plot.data.xlabel];
      const y = v[0][plot.data.ylabel];
      const xdomain = plot.xScale.domain();
      const ydomain = plot.yScale.domain();
      return (x >= xdomain[0] && x <= xdomain[1] && y >= ydomain[0] && y <= ydomain[1]);
    });
    const vertices = filtered_data.map(function(v) {
      return [
        plot.xScale(v[0][plot.data.xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
        plot.yScale(v[0][plot.data.ylabel]) + Math.random() * 1.0 - 0.5
      ];
    });

    function draw_voronoi_heat_map() {
      // add noise to coordinates of vertices in order to prevent hang-up.
      // hanging-up sometimes happen when duplicated points are included.
      const path = voronoi.selectAll("path")
        .data(d3voronoi(vertices))
        .enter()
          .append("path")
          .attr("fill", function(d, i) {
            if(filtered_data[i][1] < plot.colorScale.domain()[0]) {return "url(#TrianglePattern)";}
            if(filtered_data[i][1] > plot.colorScale.domain()[2]) {return "url(#TrianglePattern)";}
            return plot.colorScale(filtered_data[i][1]);
          })
          .attr("d", function(d) { return "M" + d.join('L') + "Z"; })
          .style("fill-opacity", 0.7)
          .style("stroke", "none");
    }
    try {
      voronoi.selectAll("path").remove();
      draw_voronoi_heat_map();
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }
  }
  update_voronoi_group();

  function update_point_group() {
    const point = plot.main_group.select("g#point-group");
    point.selectAll("circle")
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});
  }
  update_point_group();

  this.UpdateAxis();
};

ScatterPlot.prototype.AddDescription = function() {
  const plot = this;

  // description for the specification of the plot
  function add_label_table() {
  const dl = plot.description.append("dl");
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
    const actions = plot.description.append("div").attr('class', 'btn-group');
    actions.append("a")
      .attr({"class": "btn btn-primary btn-sm dropdown-toggle", "data-toggle": "dropdown", "href": "#"})
      .text("Action")
      .append("span").attr("class", "caret");
    const list = actions.append("ul").attr('class', 'dropdown-menu');
    list.append("li").append("a").attr({target: "_blank", href: plot.url}).text("show data in json");
    const downloadAsFile = function(fileName, content, a_element) {
      const blob = new Blob([content]);
      const url = window.URL || window.webkitURL;
      const blobURL = url.createObjectURL(blob);
      a_element.download = fileName;
      a_element.href = blobURL;
    };
    list.append("li").append("a").text("download svg").style("cursor", "pointer")
      .on("click", function() {
        const clone_region = document.createElement('div');
        clone_region.appendChild(plot.svg.node().cloneNode(true));
        d3.select(clone_region).select("svg")
          .attr("xmlns", "http://www.w3.org/2000/svg");
        downloadAsFile("scatter_plot.svg", $(clone_region).html(), this);
      });
    list.append("li").append("a").text("delete plot")
      .style("cursor", "pointer")
      .on("click", function() {
        plot.Destructor();
      });
    plot.description.append("div").style("margin-bottom", "20px");

    const log_check_box = plot.description.append("div").attr("class", "checkbox");
    const check_box_x_label = log_check_box.append("label").attr("id", "x_log_check");
    check_box_x_label.html('<input type="checkbox"> log scale on x axis');
    //d3.select gets the first element. This selection is available only when new svg will appear at the above of the old svg.
    d3.select('label#x_log_check input').on("change", function() {
      reset_brush(this.checked ? "log" : "linear", plot.IsLog[1] ? "log" : "linear");
    });
    log_check_box.append("br");

    const check_box_y_label = log_check_box.append("label").attr("id", "y_log_check");
    check_box_y_label.html('<input type="checkbox"> log scale on y axis');
    //d3.select gets the first element. This selection is available only when new svg will appear at the above of the old svg.
    d3.select('label#y_log_check input').on("change", function() {
      reset_brush(plot.IsLog[0] ? "log" : "linear", this.checked ? "log" : "linear");
    });

    plot.description.append("br");
    const control_plot = plot.description.append("div").style("margin-top", "10px");
    function add_brush() {
      const clone = plot.main_group.select("g#plot-group").node().cloneNode(true);
      control_plot.append("svg")
        .attr("width","210")
        .attr("height","155")
        .attr("viewBox","0 0 574 473")
        .node().appendChild(clone);

      const x = plot.IsLog[0] ? d3.scale.log() : d3.scale.linear();
      x.range([0, plot.width]);
      x.domain(plot.xScale.domain());
      const x_min = x.domain()[0];
      const x_max = x.domain()[1];

      const y = plot.IsLog[1] ? d3.scale.log() : d3.scale.linear();
      y.range([plot.height, 0]);
      y.domain(plot.yScale.domain());
      const y_min = y.domain()[0];
      const y_max = y.domain()[1];

      const brush = d3.svg.brush()
        .x(x)
        .y(y)
        .on("brush", brushed);

      const cloned_main_group = d3.select(clone)
        .attr("transform", "translate(5,5)");
      const line_shape = "M0,0V" + plot.height + "H" + plot.width;
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
        const domain = brush.empty() ? [[x_min,y_min],[x_max, y_max]] : brush.extent();
        plot.SetXDomain(domain[0][0], domain[1][0]);
        plot.SetYDomain(domain[0][1], domain[1][1]);
        plot.UpdatePlot();
        plot.UpdateAxis();
      }
    }
    add_brush();

    function reset_brush (x_linear_log, y_linear_log) {
      plot.SetXScale(x_linear_log); // reset xScale domain to draw non expanded plot
      plot.SetYScale(y_linear_log); // reset xScale domain to draw non expanded plot
      plot.UpdatePlot();
      while (control_plot.node().firstChild) {
        control_plot.node().removeChild(control_plot.node().firstChild);
      }
      add_brush();
    }

    function add_result_scale_controller() {
      const pattern = plot.main_group.select("defs").append("pattern");
      pattern
        .attr("id", "TrianglePattern")
        .attr("patternUnits", "userSpaceOnUse")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", 4)
        .attr("height", 4);
      pattern.append("rect")
        .attr("x", 1)
        .attr("y", 1)
        .attr("width", 2)
        .attr("height", 2)
        .attr("fill", "black");

      const color_scale_control = plot.description.append("div")
        .attr("id","color-scale-control")
        .style("margin-top", "10px");

      color_scale_control.text("Result range :");
      const form = color_scale_control.append("form").attr("class", "form-inline");
      form.append("input").attr({
        "type": "text",
        "class": "input-sm form-control",
        "placeholder": "min",
        "id": "range-min"
      });
      form.append("input").attr({
        "type": "text",
        "class": "input-sm form-control",
        "placeholder": "max",
        "id": "range-max"
      });

      const range_change = function(key, text_field) {
        const domain = plot.colorScale.domain();
        const original = (key == "max") ? domain[2] : domain[0];
        try{
          if(isNaN(original)) {
            alert("Do not change tha value \"NaN\"");
            text_field.value = "" + original;
            return;
          }
          if(isNaN(Number(text_field.value))) {
            alert(text_field.value + " is not a number");
            text_field.value = "" + original;
          } else if(key == "max" && Number(text_field.value) <= domain[0] ) {
            alert(text_field.value + " must be larger than min.");
            text_field.value = "" + original;
          } else if(key == "min" && Number(text_field.value) >= domain[2] ) {
            alert(text_field.value + " must be less than max.");
            text_field.value = "" + original;
          } else {
            if( key == "max" ) { domain[2] = Number(text_field.value); }
            else { domain[0] = Number(text_field.value); }
            domain[1] = (domain[0] + domain[2]) / 2.0;
            plot.colorScale.domain(domain);
            plot.colorScalePoint.domain(domain);
            reset_brush(plot.IsLog[0] ? "log" : "linear", plot.IsLog[1] ? "log" : "linear");
          }
        } catch(e) {
          alert(e);
        }
      };
      plot.description.select("#range-max")
        .attr("value", plot.colorScale.domain()[2])
        .on("change", function() {
          range_change("max", this);
        });
      plot.description.select("#range-min")
        .attr("value", plot.colorScale.domain()[0])
        .on("change", function() {
          range_change("min", this);
        });
    }
    add_result_scale_controller();
  }
  add_tools();

};

ScatterPlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_scatter_plot(url, parameter_set_base_url, current_ps_id) {
  const plot = new ScatterPlot();
  const progress = show_loading_spin_arc(plot.main_group, plot.width, plot.height);

  const xhr = d3.json(url)
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

