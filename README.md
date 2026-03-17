# Circle Packed Polygon

## Description

A circle-packed polygon is a polygon with a reference to a node graph that fully overlaps it. Each node describes a circle in the polygon. 

## The End Goal

With the node graph, we should be able to create a polygon mesh that can be partially loaded. A single node in the graph will only draw triangles new it. This will allow for partial rendering of extremely large polygonal meshes. The goal is for a user to be able to draw a polygon using a brush, and automatically have it converted into a polygon shape for terrain editing. For example, if the user wants to create an island, they draw its rough outline and then set its height and slope.
