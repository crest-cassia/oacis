function LinePlot() {
  Plot.call(this);// call constructor of Plot
}

LinePlot.prototype = Object.create(Plot.prototype);// LinePlot is sub class of Plot
LinePlot.prototype.constructor = LinePlot;// override constructor
LinePlot.prototype.IsLog = [false,false];

LinePlot.prototype.SetXScale = function(xscale) {
  let scale = null, min, max;
  switch(xscale) {
  case "linear":
    scale = d3.scale.linear().range([0, this.width]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];});});
    scale.domain([
      min,
      max
    ]).nice();
    this.IsLog[0] = false;
    break;
  case "log":
    const data_in_logscale = this.data.data.map(function(element) {
      return element.filter(function(element){
        return element[0] > 0.0;
      });
    });
    scale = d3.scale.log().clamp(true).range([0, this.width]);
    min = d3.min( data_in_logscale, function(r) { return d3.min(r, function(v) { return v[0];});});
    max = d3.max( data_in_logscale, function(r) { return d3.max(r, function(v) { return v[0];});});
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

LinePlot.prototype.SetYScale = function(yscale) {
  let scale = null, min, max;
  switch(yscale) {
  case "linear":
    scale = d3.scale.linear().range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
    scale.domain([
      min,
      max
    ]).nice();
    this.IsLog[1] = false;
    break;
  case "log":
    const data_in_logscale = this.data.data.map(function(element) {
      return element.filter(function(element){
        return element[0] > 0.0;
      });
    });
    scale = d3.scale.log().clamp(true).range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
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

LinePlot.prototype.SetXDomain = function(xmin, xmax) {
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

LinePlot.prototype.SetYDomain = function(ymin, ymax) {
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

LinePlot.prototype.AddPlot = function() {
  const plot = this;
  const colorScale = d3.scale.category10();

  function add_series_group() {
    const plot_group = plot.main_group.append("g").attr("id", "plot-group");
    const series = plot_group
      .selectAll("g")
      .data(plot.data.data)
      .enter().append("g")
        .attr("class", function(d, i) { return "series group-"+i;});

    // add line
    series.append("path")
      .attr("clip-path", "url(#clip)")
      .style({
        "stroke": function(d, i) { return colorScale(i);},
        "fill": "none",
        "stroke-width": "1.5px"
      });

    // add circle
    const tooltip = d3.select("#plot-tooltip");
    const point = series.selectAll("circle")
      .data(function(d,i) {
        return d.map(function(v) {
          return {
            x: v[0], y: v[1], yerror: v[2],
            series_index: i, series_value: plot.data.series_values[i], psid: v[3]
          };
        });
      }).enter();
    point.append("circle")
      .attr("clip-path", "url(#clip)")
      .style("fill", function(d) { return colorScale(d.series_index);})
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", 0.8);
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

    // add error bar
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror bar");
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror top");
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror bottom");
  }
  add_series_group();

  function add_legend_group() {
    const legend_region = plot.main_group.append("g")
      .attr("id", "legend-group")
      .attr("transform", "translate(" + plot.width + "," + 0 + ")");
    const legend = legend_region.append("g")
      .attr("id", "legend")
      .attr("transform", "translate(" + 0 + "," + 20 + ")");

    // add legend
    const legendItem = legend.selectAll("g")
      .data(plot.data.series_values)
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
      .text( function(d) { return d; });

    // add legend title
    const legend_title = legend_region.append("g")
      .attr("id", "legend-title");
    legend_title.append("text")
      .attr({
        x: 0,
        y: 0,
        dx: ".8em",
        dy: ".8em"
      })
      .text(plot.data.series);
  }
  add_legend_group();

  this.UpdatePlot();
};

LinePlot.prototype.UpdatePlot = function() {
  const plot = this;
  const colorScale = d3.scale.category10();
  const line = d3.svg.line()
    .x( function(d) { return plot.xScale(d[0]);} )
    .y( function(d) { return plot.yScale(d[1]);} );

  function update_series() {
    const series = plot.main_group.selectAll("g.series");
    // draw line path
    series.selectAll("path").attr("d", function(d) { return line(d);});

    // draw data point
    series.selectAll("circle")
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});

    // draw error bar
    series.selectAll(".line.yerror.bar")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x);},
        x2: function(d) { return plot.xScale(d.x);},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    series.selectAll(".line.yerror.top")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y - d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    series.selectAll(".line.yerror.bottom")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y + d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
  }
  update_series();

  this.UpdateAxis();
};

LinePlot.prototype.AddDescription = function() {
  const plot = this;

  // description for the specification of the plot
  function add_label_table() {
    const dl = plot.description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(plot.data.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(plot.data.ylabel);
    if(plot.data.series) {
      dl.append("dt").text("Series");
      dl.append("dd").text(plot.data.series);
    }
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
    const plt_url = plot.url.replace(/\.json/, '.plt');
    list.append("li").append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
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
        downloadAsFile("line_plot.svg", $(clone_region).html(), this);
      });
    list.append("li").append("a").text("delete plot")
      .style("cursor", "pointer")
      .on("click", function() {
        plot.Destructor();
      });
    plot.description.append("div").style("padding-bottom", "50px");

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
  }
  add_tools();

};

LinePlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_line_plot(url, parameter_set_base_url, current_ps_id) {
  const plot = new LinePlot();
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

