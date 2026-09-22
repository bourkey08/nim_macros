#----------------------------------------------------
#    Type definitions for the double linked lru list
#----------------------------------------------------

#Implement a doubly linked list for efficient tracking of least recently used memory entry
type DLinkListNode[K, V] = ref object
    prev: DLinkListNode[K, V]
    next: DLinkListNode[K, V]
    key: K
    value: V

type DLinkList*[K, V] = ref object
    head: DLinkListNode[K, V]
    tail: DLinkListNode[K, V]
    index: Table[K, DLinkListNode[K, V]]#Index for O(1) access to nodes in the list
    len: int 
    maxLen: int = 0#Max length of the list, if 0 then the list can grow indefinitely