#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                            Implements a doubly linked list suitable for use as a lru cache
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[tables]

include "./dbl_link_list_types.nim"


proc newDLinkList*[K, V](maxLen: int = 0): DLinkList[K, V] =
    result = DLinkList[K, V](
        head: nil,
        tail: nil,
        len: 0,
        maxLen: maxLen
    )

proc contains*[K, V](self: DLinkList[K,V], key: K): bool {.inline.}=
    if key in self.index:
        return true
    else:
        return false

proc del*[K, V](self: DLinkList[K,V], key: K) {.inline.} =
    #Get the entry from the index and then remove it from the list
    let entry = self.index[key]
    self.index.del(key)
    self.len -= 1

    #Check if the entry is the head or tail and handle these accordingly
    if entry == self.head and entry == self.tail:
        self.head = nil
        self.tail = nil

    elif entry == self.head:
        self.head = entry.next
        self.head.prev = nil

    elif entry == self.tail:
        self.tail = entry.prev

    else:#Entry is neither head or tail, update the prev and next entries to point to each other to remove the entry from the list
        entry.prev.next = entry.next
        entry.next.prev = entry.prev

proc `[]=`*[K, V](self: DLinkList[K,V], key: K, value: V) {.inline.} =
    #Check if the entry exist in the list and if it does then update it
    if key in self:
        let entry = self.index[key]

        #Update the value and move it to the head of the list to mark it as most recently used
        entry.value = value
        
        #First update the prev and next entries to remove this entry from its current position in the list
        if entry == self.head:#Entry is already the head so just return
            return

        elif entry == self.tail:#Entry is currently the last entry in the list, update the tail to be the previous entry
            self.tail = entry.prev
            self.tail.next = nil

        else:#Entry is in the middle of the list, update the prev and next entries to point to each other to remove this entry from its current position in the list
            entry.prev.next = entry.next
            entry.next.prev = entry.prev

        #Move the entry to the head of the list        entry.prev = nil
        entry.next = self.head#Copy the current head to the next pointer of this entry (2nd in list)
        self.head = entry
        self.head.prev = nil

    else:
        #Create a new entry and insert it at the head of the list
        let entry = DLinkListNode[K, V](
            key: key,
            value: value
        )
        self.len += 1#Adding an entry so increment the length

        entry.next = self.head#Copy the current head to the next pointer of this entry (2nd in list)
        self.head = entry        

        #As this is a new entry set the index
        self.index[key] = entry

    #Update the next entry in the list to have the correct prev entry
    if cast[int](self.head.next) == 0:
        self.tail = self.head
    else:
        self.head.next.prev = self.head#The next entry in the list should have this entry as its prev entry

    #Handle applying the max length limit if one is set
    if self.maxLen > 0 and self.len > self.maxLen:
        self.del(self.tail.key)

proc `[]`*[K, V](self: DLinkList[K,V], key: K): V {.inline.} =
    let entry = self.index[key]
    
    #Move the entry to the head of the list to mark it as the mru entry
    if entry == self.head:#Entry is already the head so just return the value
        return entry.value

    elif entry == self.tail:#Entry is currently the last entry in the list, update the tail to be the previous entry
        self.tail = entry.prev
        self.tail.next = nil

    else:#Entry is in the middle of the list, update the prev and next entries to point to each other to remove this entry from its current position in the list
        entry.prev.next = entry.next
        entry.next.prev = entry.prev

    #Move the entry to the head of the list
    entry.prev = nil
    entry.next = self.head#Set the current head as the next pointer of this entry (2nd in list)
    self.head = entry
    self.head.next.prev = self.head#The next entry in the list should have this entry as its prev entry

    return entry.value

template pop*[K, V](self: DLinkList[K,V]): (K, V) =
    if cast[int](self.tail) == 0:
        raise newException(ValueError, "Cannot pop from an empty list")
    let entry = self.tail
    self.del(entry.key)
    (entry.key, entry.value)

template shift*[K, V](self: DLinkList[K,V]): (K, V) =
    if cast[int](self.head) == 0:
        raise newException(ValueError, "Cannot shift from an empty list")

    let entry = self.head
    self.del(entry.key)
    (entry.key, entry.value)

template peekPop*[K, V](self: DLinkList[K,V]): (K, V) =
    if cast[int](self.tail) == 0:
        raise newException(ValueError, "Cannot pop from an empty list")
    let entry = self.tail
    (entry.key, entry.value)

template peekShift*[K, V](self: DLinkList[K,V]): (K, V) =
    if cast[int](self.head) == 0:
        raise newException(ValueError, "Cannot shift from an empty list")
    let entry = self.head
    (entry.key, entry.value)

#Implement alternative access methods as templates
template get*[K, V](self: DLinkList[K,V], key: K): V =
    self[key]

template set*[K, V](self: DLinkList[K,V], key: K, value: V) =
    self[key] = value

template delete*[K, V](self: DLinkList[K,V], key: K) =
    self.del(key)

template put*[K, V](self: DLinkList[K,V], key: K, value: V) =
    self[key] = value
