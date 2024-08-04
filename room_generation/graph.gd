class_name RoomGraph
extends RefCounted


class RoomGraphNode:
	var id: int
	var value: RoomGenerator.Room 
	var nodes: Array[RoomGraphNode]	

	
	func _init(i: int , v: RoomGenerator.Room):
		id = i
		value = v 
		nodes = []

class RoomGraphEdge:
	var weight: float
	var node_a: RoomGraphNode
	var node_b: RoomGraphNode

	func _init(w, a, b):
		weight = w
		node_a = a
		node_b = b
	
	


var nodes: Dictionary = {}
var edges: Array[RoomGraphEdge]

func add_node(id: int, value: RoomGenerator.Room):
	if not nodes.has(id):
		nodes[id] = RoomGraphNode.new(id, value)

func add_edge(id1: int, id2: int, weight: float):
	if nodes.has(id1) and nodes.has(id2):
		var edge: RoomGraphEdge = RoomGraphEdge.new(weight, nodes.get(id1), nodes.get(id2))
		if not edges.has(edge):
			edges.append(edge)
		if not nodes.get(id1).nodes.has(nodes.get(id2)):
			nodes.get(id1).nodes.append(nodes.get(id2))
		if not nodes.get(id2).nodes.has(nodes.get(id1)):
			nodes.get(id2).nodes.append(nodes.get(id1))
	

func get_node(id: int) -> RoomGraphNode:
	return nodes.get(id)


func get_nodes_ids(array: Array[RoomGraphNode]) -> Array:
	return array.map(func(node): return node.id)

func print_edges():
	for edge in edges:
		printt("w: %d	a: %d	b: %d" % [edge.weight, edge.node_a.id, edge.node_b.id])

