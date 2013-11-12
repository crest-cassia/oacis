function show_parameter_progress(url) {
  var margin = {top: 10, right: 0, bottom: 10, left: 0},
      width = 720,
      height = 720;
  var rowLabelMargin = 100;
  var columnLabelMargin = 100;

  var colorScale = d3.scale.linear().domain([0.0,1.0])
    .range(["#dddddd", "#62c462"]);

  var cmap = d3.select('svg#colormap-svg')
    .attr("width", 200)
    .attr("height", 20);
  cmap.selectAll("rect")
    .data([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
    .enter().append("rect")
    .attr({
      x: function(d, i) { return i * 20.0;},
      y: 0.0,
      width: 19,
      height: 19,
      fill: function(d) { return colorScale(d); }
    });

  var toolTip = d3.select("#progress-tooltip")
    .style("opacity", 0);

  d3.json(url, function(dat) {

    var rectSizeX = (width - rowLabelMargin) / dat.parameter_values[0].length;
    var rectSizeY = (height - columnLabelMargin) / dat.parameter_values[1].length;

    var svg = d3.select("svg#progress-overview")
      .attr("id", "canvas")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    svg.append("line")
      .attr({
        x1: 0, y1: columnLabelMargin - 2,
        x2: width, y2: columnLabelMargin - 2,
        stroke: "black",
        "stroke-width": 1
      });
    svg.append("line")
      .attr({
        x1: rowLabelMargin-2, y1: 0,
        x2: rowLabelMargin-2, y2: height,
        stroke: "black",
        "stroke-width": 1
      });
    
    var rectRegion = svg.append("g")
      .attr("transform", "translate(" + rowLabelMargin + "," + columnLabelMargin + ")");

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
          "stroke-width": 2,
          "opacity": 0
        })
        .on("mouseover", function(d) {
          if( d[1] > 0.0 ) {
            toolTip.transition()
              .duration(200)
              .style("opacity", .8);
            toolTip.html( "Finished/Total: " + d[0] + " / " + d[1] + "<br />Total: " + 100.0*d[0]/d[1] + " %")
              .style("left", d3.event.pageX + "px")
              .style("top", (d3.event.pageY-28) + "px");
          }
        })
        .on("mousemove", function(d) {
          toolTip.style("left", d3.event.pageX +  "px")
            .style("top", (d3.event.pageY-28) + "px");
        })
        .on("mouseout", function(d) {
          toolTip.transition()
            .duration(500)
            .style("opacity", 0);
        })
        .transition()
        .duration(1000)
        .delay( function(d,i) {return i*100;} )
        .attr({
          "opacity": function(d) {
            if( d[1] > 0.0 ) { return 1.0; }
            else { return 0.0; }
          }
        });

    var rowLabelRegion = svg.append("g")
      .attr("transform", "translate(" + 0 + "," + columnLabelMargin + ")");
    rowLabelRegion.selectAll("text")
      .data(dat.parameter_values[1])
      .enter().append("text")
      .attr("x", rowLabelMargin)
      .attr("y", function(d,i) {
        return (i + 0.5) * rectSizeY;
      })
      .attr("dx", "-10")
      .attr("dy", "5")
      .attr("text-anchor", "end")
      .text(function(d) { return d;});

    rowLabelRegion.append("text")
      .attr({
        x: rowLabelMargin / 2,
        y: -7,
        "text-anchor": "middle"
      })
      .text(dat.parameters[1]);


    var columnLabelRegion = svg.append("g")
      .attr("transform", "translate(" + rowLabelMargin + "," + columnLabelMargin + ") rotate(-90)");
    columnLabelRegion.selectAll("text")
      .data(dat.parameter_values[0])
      .enter().append("text")
      .attr("x", 0)
      .attr("y", function(d,i) {
        return (i+0.5) * rectSizeX;
      })
      .attr("dx", "10")
      .attr("dy", "5")
      .attr("text-anchor", "start")
      .text(function(d) { return d; });

    columnLabelRegion.append("text")
      .attr({
        x: columnLabelMargin / 2,
        y: -7,
        "text-anchor": "middle"
      })
      .text(dat.parameters[0]);

  })
};
