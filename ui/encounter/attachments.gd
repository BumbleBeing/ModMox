class_name Attachments
extends RefCounted
## Which permanents are drawn attached to which (game ADR 0042). An attachment, such as an
## Equipment, is drawn behind the permanent it is attached to when that permanent stands in
## the line being drawn, and an Aura on a land behind that land in its row, whoever controls
## either; any other stands on its own like every other permanent.


## The attachments among [param permanents] drawn with each of [param host_ids], by the ID
## of what each is attached to, in object ID order: the first lies nearest its permanent.
static func by_host(permanents: Array[MmObjectView], host_ids: Array[int]) -> Dictionary[int, Array]:
	var attached: Dictionary[int, Array] = {}
	var sorted: Array[MmObjectView] = permanents.duplicate()
	sorted.sort_custom(func(a: MmObjectView, b: MmObjectView) -> bool: return a.id < b.id)
	for permanent: MmObjectView in sorted:
		if is_drawn_attached(permanent, host_ids):
			if not attached.has(permanent.attached_to_object_id):
				attached[permanent.attached_to_object_id] = []
			attached[permanent.attached_to_object_id].append(permanent)
	return attached


## Whether [param permanent] is drawn behind one of [param host_ids].
static func is_drawn_attached(permanent: MmObjectView, host_ids: Array[int]) -> bool:
	return permanent.attached_to_object_id != 0 and host_ids.has(permanent.attached_to_object_id)
