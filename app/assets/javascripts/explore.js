function get_current_ps() {
  return $('#current_ps_id').text();
}

function set_current_ps(ps_id) {
  $('#current_ps_id').text(ps_id);

  d3.selectAll("circle")
    .attr("r", function(d) { return (d.psid == ps_id) ? 5 : 3;});

  var url = $('#plot').data('ps-url').replace('PSID', ps_id);
  d3.json(url, function(error, json) {
    var param_values = json.v;
    for(var key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }
  });
}

function get_current_parameter_values() {
  var parameter_values = {};
  $('td[id^="ps_v_"]').each( function(){
    var key = $(this).attr('id').replace('ps_v_', '');
    parameter_values[key] = $(this).text();
  });
  return parameter_values;
}

function move_current_ps(neighbor_ps_url) {
  var current_ps_id = get_current_ps();
  var url = neighbor_ps_url.replace('PSID', current_ps_id);

  d3.json(url, function(error, json) {
    // update table
    var ps_id = json._id;
    $('#current_ps_id').text(ps_id);
    var param_values = json.v;
    for(var key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }

    // update scatter plot
    update_explorer(ps_id);
  });
}

function build_scatter_plot_url(ps_id) {
  ps_id = ps_id || $('td#current_ps_id').text();
  var x = $('#scatter-plot-form #x_axis_key').val();
  var y = $('#scatter-plot-form #y_axis_key').val();
  var result = $('#scatter-plot-form #result').val();
  var irrelevants = $('#irrelevant-params').children("input:checkbox:checked").map(function() {
    return this.id;
  }).get();
  irrelevants = irrelevants.concat(range_modified_keys()).join(',');

  var url = $('#plot').data('scatter-plot-url').replace('PSID', ps_id);
  var range = {};
  range_modified_keys().forEach( function(key) {
    range[key] = get_current_range_for(key);
  });
  var url_with_param = url +
    "?x_axis_key=" + encodeURIComponent(x) +
    "&y_axis_key=" + encodeURIComponent(y) +
    "&result=" + encodeURIComponent(result) +
    "&irrelevants=" + encodeURIComponent(irrelevants) +
    "&range=" + encodeURIComponent( JSON.stringify(range) );
  return url_with_param;
}

function draw_explorer(current_ps_id) {
  var margin = {top: 10, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;

  var plot_region = d3.select("#plot");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom,
      "id": "plot-svg"
    });

  // add group for color map
  svg.append("g")
    .attr({
      "transform": "translate(" + (margin.left + width) + "," + margin.top + ")",
      "id": "color-map-group"
    });
  // add group for plot region
  svg.append("g")
    .attr({
      "transform": "translate(" + margin.left + "," + margin.top + ")",
      "id": "plot-group"
    });

  // add group for loading spin
  var color_map_group_height = 180;
  svg.append("g")
    .attr({
      "transform": "translate(" + (margin.left + width) + "," + (margin.top + color_map_group_height) + ")",
      "id": "progress_arc_group"
    });

  update_explorer(current_ps_id, {});
}

// to clear current range, set range to null
function set_current_range_for(parameter_key, range) {
  $('td#ps_v_' + parameter_key).data('current-range', range);
}

function get_current_range_for(parameter_key) {
  var current = $('td#ps_v_' + parameter_key).data('current-range');
  if( !current ) {
    current = $('td#ps_v_' + parameter_key).data('range');
  }
  return current;
}

function range_modified_keys() {
  var modified_key = [];
  $('td[id^="ps_v_"]').each( function(){
    if( $(this).data('current-range') ) {
      var key = $(this).attr('id').replace('ps_v_', '');
      modified_key.push(key);
    }
  });
  return modified_key;
}

function update_explorer(current_ps_id) {
  var width = 560;
  var height = 460;
  var colorMapG = d3.select("g#color-map-group");
  var svg = d3.select("g#plot-group");
  if( !current_ps_id ) { current_ps_id = get_current_ps(); }

  var url = build_scatter_plot_url(current_ps_id);

  function show_progress_arc() {
    var g = d3.select('#progress_arc_group');
    var spin_size = 100;
    var progress = show_loading_spin_arc(g, spin_size, spin_size);
    return progress;
  }
  var progress = show_progress_arc();

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var xScale = d3.scale.linear().range([0, width]);
    var xlabel = $('select#x_axis_key option:selected').text();
    var xDomain = get_current_range_for(xlabel);
    xScale.domain(xDomain).nice();

    var yScale = d3.scale.linear().range([height, 0]);
    var ylabel = $('select#y_axis_key option:selected').text();
    var yDomain = get_current_range_for(ylabel);
    yScale.domain(yDomain).nice();

    var colorScale;
    var result_domain = $('select#result option:selected').data("domain");
    if( result_domain ) {
      colorScale = d3.scale.linear().range(["#0041ff", "#ff2800"]);
      colorScale.domain(result_domain).nice();
    }
    window.color_scale = colorScale;

    function find_current_parameter_set() {
      var psids = dat.data.map(function(v) { return v[3]; });
      var idx = psids.indexOf(current_ps_id);
      if( idx == -1 ) {
        var values = get_current_parameter_values();
        var current_x = xScale( +values[xlabel] );
        var current_y = yScale( +values[ylabel] );
        var distances = dat.data.map(function(v) {
          var dx = xScale(v[0][xlabel]) - current_x;
          var dy = yScale(v[0][ylabel]) - current_y;
          return dx*dx + dy*dy;
        });
        idx = distances.indexOf( Math.min.apply(null, distances) );
        current_ps_id = psids[idx];
        set_current_ps(current_ps_id);
      }
    }
    find_current_parameter_set();

    function draw_color_map(g) {
      var scale = d3.scale.linear().domain([0.0, 1.0]).range(colorScale.range());
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
        .text( colorScale.domain()[1] );
      g.append("text")
        .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[0] );
    }
    colorMapG.selectAll("text").remove();
    colorMapG.selectAll("rect").remove();
    if( colorScale ) { draw_color_map(colorMapG); }

    function draw_axes(xlabel, ylabel) {
      d3.selectAll("g.axis").remove();
      // X-Axis
      var xAxis = d3.svg.axis()
        .scale(xScale)
        .orient("bottom");
      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .attr("id", "scatter-plot-x-axis")
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
        .attr("id", "scatter-plot-y-axis")
        .call(yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("x", -height/2)
          .attr("y", -50.0)
          .style("text-anchor", "middle")
          .text(ylabel);
    }
    draw_axes(dat.xlabel, dat.ylabel);

    function draw_voronoi_heat_map() {
      var xlabel = dat.xlabel;
      var ylabel = dat.ylabel;

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
      var path = svg.append("g")
        .attr("id", "voronoi-group")
        .selectAll("path")
        .data(voronoi(vertices));
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(dat.data[i][1]);})
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .style("fill-opacity", 0.7)
        .style("stroke", "none");
    }
    try {
      d3.select("g#voronoi-group").remove();
      if( colorScale ) { draw_voronoi_heat_map(); }
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }

    function draw_points() {
      var tooltip = d3.select("#plot-tooltip");

      var xlabel = dat.xlabel;
      var ylabel = dat.ylabel;
      var mapped = dat.data.map(function(v) {
        return {
          x: v[0][xlabel],
          y: v[0][ylabel],
          average: v[1],
          error: v[2],
          psid: v[3]
        };
      });

      d3.select("#circles").remove();
      var point = svg
        .append("g")
        .attr("id", "circles")
        .selectAll("circle").data(mapped);

      point.exit().remove();
      point.enter().append("circle");
      point
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function(d) {
          if( colorScale) { return colorScale(d.average); }
          else { return "black"; }
        })
        .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;})
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", 0.8);
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
        .on("click", function(d) {
          set_current_ps(d.psid);
        })
        .on("dblclick", function(d) {
          var ps_url = $('#plot').data('ps-url').replace('PSID', d.psid);
          // open a link in a background window
          window.open(ps_url, '_blank');
        });
    }
    draw_points();

    update_pc_plot(dat.data, current_ps_id);
  })
  .on("error", function() { console.log("error"); /*progress.remove(); */})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    progress.remove();
  });
}

function initialize_pc_plot() {
  var margin = {top: 50, right: 100, bottom: 50, left: 100};
  var width = 1000;
  var height = 200;

  var plot_region = d3.select("#pc-plot");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom,
      "id": "pc-plot-svg"
    })
    .append("g")
    .attr({
      "transform": "translate(" + margin.left + "," + margin.top + ")",
      "id": "pc-plot-group"
    });

  var dimensions = [];
  var yScales = {};
  function set_scales_and_dimensions() {
    $('select#x_axis_key option').each(function() {
      var key = $(this).text();
      var domain = get_current_range_for(key);
      var scale = d3.scale.linear().domain(domain).range([height, 0]).nice();
      yScales[key] = scale;
      dimensions.push(key);
    });
  }
  set_scales_and_dimensions();

  window.pcp_x_scale = d3.scale.ordinal().rangePoints([0,width], 1).domain( dimensions );
  window.pcp_y_scales = yScales;

  function draw_axis() {
    var xScale = window.pcp_x_scale;
    var dimension_g = svg.selectAll(".dimension")
      .data(dimensions)
      .enter().append("svg:g")
      .attr("class", "dimension")
      .attr("transform", function(d) { return "translate(" + xScale(d) + ")"; });

    var axis = d3.svg.axis().orient("left");
    dimension_g.append("svg:g")
      .attr("class", "pcp-axis")
      .each(function(d) {
        d3.select(this).call( axis.scale(yScales[d]) );
      })
      .append("svg:text")
      .attr("text-anchor", "middle")
      .attr("y", -9)
      .text(String); // set text to the data values
  }
  draw_axis();

  function set_brsuh() {
    svg.selectAll(".dimension").each(function(d) {
      var brush = d3.svg.brush().y( window.pcp_y_scales[d] ).on("brushend", on_brush_end);
      function on_brush_end() {
        var domain = brush.empty() ? null : brush.extent();
        set_current_range_for( d, domain );
        update_explorer();
      }
      d3.select(this).append("svg:g")
        .attr("class", "brush")
        .call(brush)
        .selectAll("rect")
        .attr("x", -8)
        .style({stroke: "orange", "fill-opacity": 0.125, "shape-rendering": "crispEdges"})
        .attr("width", 16);
    });
  }
  set_brsuh();
}

function update_pc_plot(data, current_ps_id) {
  var svg = d3.select('#pc-plot-group');
  var dimensions = svg.selectAll(".dimension").data();
  var xScale = window.pcp_x_scale;
  var yScales = window.pcp_y_scales;

  function redraw_path() {
    d3.selectAll('g.pcp-path').remove();
    var pcp_path = svg.append("svg:g")
      .attr("class", "pcp-path")
      .selectAll("path")
      .data(data);
    pcp_path.enter().append("svg:path");
    pcp_path
      .style({ "fill": "none", "stroke-opacity": 0.7})
      .attr("d", function(d) {
        var points = dimensions.map( function(p) {
          return [ xScale(p), yScales[p]( d[0][p] ) ];
        });
        return d3.svg.line()(points);
      })
      .attr("stroke-width", function(d) {
        return d[3] == current_ps_id ? 3 : 1;
      })
      .attr("stroke", function(d) {
        if( window.color_scale ) { return window.color_scale(d[1]); }
        else { return "steelblue"; }
      });
  }
  redraw_path();
}
