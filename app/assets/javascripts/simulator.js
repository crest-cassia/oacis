//= require d3

function draw_color_map() {
  var colorScale = d3.scale.linear().domain([0.0,1.0])
    .range(["#dddddd", "#0041ff"]);
  var cmap = d3.select('svg#colormap-svg')
    .attr("width", 180)
    .attr("height", 30);
  cmap.selectAll("rect")
    .data([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
    .enter().append("rect")
    .attr({
      x: function(d, i) { return i * 30.0;},
      y: 0.0,
      width: 29,
      height: 29,
      fill: function(d) { return colorScale(d); }
    });
};

function show_loading_spin_arc(svg, width, height) {
  var loading_spin = svg.append("g")
    .attr("transform", "translate(" + width/2 + "," + height/2 + ")")
    .attr("id", "loading-spin");
  var radius = Math.min(width, height) / 2;
  var arc = d3.svg.arc()
    .innerRadius(radius*0.5)
    .outerRadius(radius*0.9)
    .startAngle(0);
  loading_spin.append("path")
    .datum({endAngle: 0.66*Math.PI})
    .style("fill", "#4D4D4D")
    .attr("d", arc)
    .call(spin, 1500);
  var message = radius > 100 ? "LOADING: click here to cancel" : "LOADING";
  loading_spin.append("text")
    .style({
      "text-anchor": "middle",
      "font-size": radius*0.1
    })
    .text(message);

  function spin(selection, duration) {
    selection.transition()
      .ease("linear")
      .duration(duration)
      .attrTween("transform", function() {
        return d3.interpolateString("rotate(0)", "rotate(360)");
      });
    setTimeout( function() { spin(selection, duration); }, duration);
  };
  return loading_spin;
}

function draw_progress_overview(url) {
  var colorScale = d3.scale.linear().domain([0.0,1.0])
    .range(["#dddddd", "#0041ff"]);

  var margin = {top: 10, right: 0, bottom: 10, left: 0},
      width = 720,
      height = 720;
  var rowLabelMargin = 100;
  var columnLabelMargin = 100;
  var tickTextOffset = [10, 5];
  var labelTextOffset = {column: -7, row: 2};
  var fontsize =12;

  var toolTip = d3.select("#progress-tooltip");

  var progress_overview = d3.select("#progress-overview");
  progress_overview.select("svg").remove();
  var svg = progress_overview.append("svg")
    .attr("id", "canvas")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom);
  var loading = show_loading_spin_arc(svg, svg.attr("width"), svg.attr("height"));

  var xhr = d3.json(url)
    .on("load", function(dat) {
    loading.remove();

    var rectSizeX = (width - rowLabelMargin) / dat.parameter_values[0].length;
    var rectSizeY = (height - columnLabelMargin) / dat.parameter_values[1].length;

    var drag_flag = 0;
    var mousedownX = 0;
    var mousedownY = 0;
    var mousedragX = 0;
    var mousedragY = 0;
    var vbox_x = 0;
    var vbox_y = 0;
    var vbox_default_width = vbox_width = width - columnLabelMargin;
    var vbox_default_height = vbox_height = height - rowLabelMargin;
    var zoom_scale=1.0;

    function adjust_boundary_conditions(x, y) {
      if (x < 0) {
        x=0;
      }
      if (y < 0) {
        y=0;
      }
      if (x + vbox_width > vbox_default_width) {
        x=vbox_default_width-vbox_width;
      }
      if (y + vbox_height > vbox_default_height) {
        y=vbox_default_height-vbox_height;
      }
      return [x,y];
    };

    function set_view_box(x, y) {
      d3.select('svg#inner_canvas')
        .attr("viewBox", "" + x + " " + y + " " + vbox_width + " " + vbox_height);
      d3.select('svg#rowLabel_canvas')
        .attr("viewBox", "" + 0 + " " + y + " " + (rowLabelMargin-tickTextOffset[0]) + " " + vbox_height);
      d3.select('svg#columnLabel_canvas')
        .attr("viewBox", "" + x + " " + 0 + " " + vbox_width + " " + (columnLabelMargin-tickTextOffset[1]));
    };

    function mouse_zoom(eventObject) {
      var center = d3.mouse(eventObject);
      vbox_width = vbox_default_width * zoom_scale;
      vbox_height = vbox_default_height * zoom_scale;
      vbox_x = center[0] - vbox_width/2;
      vbox_y = center[1] - vbox_height/2;
      var vboxes = adjust_boundary_conditions(vbox_x, vbox_y);
      vbox_x=vboxes[0];
      vbox_y=vboxes[1];
      set_view_box(vbox_x,vbox_y);
      d3.select('g#rowLabelRegion')
        .attr("font-size",fontsize*Math.sqrt(zoom_scale));
      d3.select('g#columnLabelRegion')
        .attr("font-size",fontsize*Math.sqrt(zoom_scale));
    };



    var inner_svg = svg.append("svg")
      .attr("id", "inner_canvas")
      .attr("x", margin.left + rowLabelMargin)
      .attr("y", margin.top + columnLabelMargin)
      .attr("width", width - rowLabelMargin)
      .attr("height", height - columnLabelMargin)
      .attr("viewBox", "" + vbox_x + " " + vbox_y + " " + vbox_width + " " + vbox_height)
      .append("g")
      .on("mouseup", function() {
        if (drag_flag==1) {
          mousedragX = d3.event.pageX - mousedownX;
          mousedragY = d3.event.pageY - mousedownY;
          vbox_x -= mousedragX * zoom_scale;
          vbox_y -= mousedragY * zoom_scale;
          var vboxes = adjust_boundary_conditions(vbox_x, vbox_y);
          vbox_x=vboxes[0];
          vbox_y=vboxes[1];
          set_view_box(vbox_x,vbox_y);
        }
      })
      .on("mousemove", function() {
          drag_flag = 1;
      })
      .on("mousedown", function() {
          drag_flag = 0;
          mousedownX = d3.event.clientX;
          mousedownY = d3.event.clientY;
      })
      .on("mousewheel", function() {
        if (d3.event.wheelDelta==120) {
          zoom_scale *= 0.75;
        } else if (d3.event.wheelDelta==-120) {
          zoom_scale /= 0.75;
          if (zoom_scale>=1) {
            zoom_scale=1;
          }
        }
        mouse_zoom(this);
      })
      .on("DOMMouseScroll", function() {
        if (d3.event.detail==-3) {
          zoom_scale *= 0.75;
        } else if (d3.event.detail==3) {
          zoom_scale /= 0.75;
          if (zoom_scale>=1) {
            zoom_scale=1;
          }
        }
        mouse_zoom(this);
      });

    svg.append("line")
      .attr({
        x1: 0, y1: margin.top+columnLabelMargin-2,
        x2: width, y2: margin.top+columnLabelMargin-2,
        stroke: "black",
        "stroke-width": 1
      });
    svg.append("line")
      .attr({
        x1: margin.left+rowLabelMargin-2, y1: 0,
        x2: margin.left+rowLabelMargin-2, y2: height,
        stroke: "black",
        "stroke-width": 1
      });
    
    var rectRegion = inner_svg.append("g");

    var row = rectRegion.selectAll("g")
      .data(dat.num_runs)
      .enter().append("g")
        .attr("transform", function(d, i) {
          return "translate(" + 0 + "," + i*rectSizeY + ")"
        });

    row.selectAll("rect")
      .data( function(d) { return d;})
      .enter().append("rect")
        .attr({
          x: function(d,i) {
            return i*rectSizeX;
          },
          y: 0,
          width: rectSizeX,
          height: rectSizeY,
          rx: 5,
          ry: 5,
          fill: function(d) {
            if( d[1] > 0.0 ) { return colorScale(d[0]/d[1]); }
            else { return "white"; }
          },
          stroke: "white",
          "stroke-width": 2
        })
        .on("mouseover", function(d) {
          if( d[1] > 0.0 ) {
            toolTip.transition()
              .duration(200)
              .style("opacity", .8);
            toolTip.html( "Finished/Total: " + d[0] + " / " + d[1] + "<br />Total: " + 100.0*d[0]/d[1] + " %")
              .style("left", (d3.event.pageX+10) + "px")
              .style("top", (d3.event.pageY-28) + "px");
          }
        })
        .on("mousemove", function(d) {
          toolTip.style("left", (d3.event.pageX+10) +  "px")
            .style("top", (d3.event.pageY-28) + "px");
        })
        .on("mouseout", function(d) {
          toolTip.transition()
            .duration(500)
            .style("opacity", 0);
        });

    var rowLabelKeyRegion = svg.append("g")
      .attr("transform", "translate(" + 0 + "," + columnLabelMargin + ")");

    rowLabelKeyRegion.append("text")
      .attr({
        x: rowLabelMargin / 2,
        y: labelTextOffset.row,
        "text-anchor": "middle"
      })
      .text(dat.parameters[1]);

    var rowLabelsvg = svg.append("svg")
      .attr("id", "rowLabel_canvas")
      .attr("x", margin.left)
      .attr("y", margin.top + columnLabelMargin)
      .attr("width", rowLabelMargin-tickTextOffset[0])
      .attr("height", height - columnLabelMargin)
      .attr("preserveAspectRatio", "none")
      .attr("viewBox", "" + 0 + " " + vbox_y + " " + rowLabelMargin-tickTextOffset[0] + " " + vbox_height);

    var rowLabelRegion = rowLabelsvg.append("g")
      .attr("id","rowLabelRegion")
      .attr("font-size",fontsize);

    rowLabelRegion.selectAll("text")
      .data(dat.parameter_values[1])
      .enter().append("text")
      .attr({
        "x": rowLabelMargin-tickTextOffset[0],
        "y": function(d,i) { return (i + 0.5) * rectSizeY; },
        "dx": -tickTextOffset[0],
        "dy": tickTextOffset[1],
        "text-anchor": "end"
      })
      .text(function(d) { return d;});

    var columnLabelKeyRegion = svg.append("g")
      .attr("transform", "translate(" + rowLabelMargin + "," + columnLabelMargin + ") rotate(-90)");

    columnLabelKeyRegion.append("text")
      .attr({
        x: columnLabelMargin / 2,
        y: labelTextOffset.column,
        "text-anchor": "middle"
      })
      .text(dat.parameters[0]);

    var columnLabelsvg = svg.append("svg")
      .attr("id", "columnLabel_canvas")
      .attr("x", margin.left + rowLabelMargin)
      .attr("y", margin.top)
      .attr("width", width - rowLabelMargin)
      .attr("height", columnLabelMargin-tickTextOffset[1])
      .attr("preserveAspectRatio", "none")
      .attr("viewBox", "" + vbox_x + " " + 0 + " " + vbox_width + " " + columnLabelMargin-tickTextOffset[1]);

    var columnLabelRegion = columnLabelsvg.append("g")
      .attr("id","columnLabelRegion")
      .attr("font-size",fontsize)
      .attr("transform", "translate(" + 0 + "," + columnLabelMargin + ") rotate(-90)");

    columnLabelRegion.selectAll("text")
      .data(dat.parameter_values[0])
      .enter().append("text")
      .attr({
        "x": 0,
        "y": function(d,i) { return (i+0.5) * rectSizeX;},
        "dx": tickTextOffset[0],
        "dy": tickTextOffset[1],
        "text-anchor": "start"
      })
      .text(function(d) { return d; });
  })
  .on("error", function() { loading.remove(); })
  .get();

  loading.on("mousedown", function() {
    xhr.abort();
    loading.remove();
  })
};
