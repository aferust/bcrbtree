/**
This module implements a red-black tree container.
This module is a submodule of $(MREF std, container).
Source: $(PHOBOSSRC std/container/rbtree.d)
Copyright: Red-black tree code copyright (C) 2008- by Steven Schveighoffer. Other code
copyright 2010- Andrei Alexandrescu. All rights reserved by the respective holders.
License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(HTTP
boost.org/LICENSE_1_0.txt)).
Authors: Steven Schveighoffer, $(HTTP erdani.com, Andrei Alexandrescu)
*/
module bcrbtree.bcrbtree;

import std.functional : binaryFun;

public import std.container.util;


struct RBNode(V)
{
    /*
     * Convenience alias
     */
    alias Node = RBNode*;

    private Node _left;
    private Node _right;
    private Node _parent;

    /**
     * The value held by this node
     */
    V value;

    /**
     * Enumeration determining what color the node is.  Null nodes are assumed
     * to be black.
     */
    enum Color : byte
    {
        Red,
        Black
    }

    /**
     * The color of the node.
     */
    Color color;

    /**
     * Get the left child
     */
    @property inout(RBNode)* left() inout
    {
        return _left;
    }

    /**
     * Get the right child
     */
    @property inout(RBNode)* right() inout
    {
        return _right;
    }

    /**
     * Get the parent
     */
    @property inout(RBNode)* parent() inout
    {
        return _parent;
    }

    void deallocate(){
        destroyFree(&this);
    }

    /**
     * Set the left child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * $(RED Warning: If the node this is called on is a local variable, a stack pointer can be
     * escaped through `newNode.parent`. It's marked `@trusted` only for backwards compatibility.)
     *
     * Returns newNode
     */
    @property Node left(return scope Node newNode) @trusted
    {
        _left = newNode;
        if (newNode !is null)
            newNode._parent = &this;
        return newNode;
    }

    /**
     * Set the right child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * $(RED Warning: If the node this is called on is a local variable, a stack pointer can be
     * escaped through `newNode.parent`. It's marked `@trusted` only for backwards compatibility.)
     *
     * Returns newNode
     */
    @property Node right(return scope Node newNode) @trusted
    {
        _right = newNode;
        if (newNode !is null)
            newNode._parent = &this;
        return newNode;
    }

    // assume _left is not null
    //
    // performs rotate-right operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P         P
    //      |   ->    |
    //      T         L
    //     / \       / \
    //    L   R     a   T
    //   / \           / \
    //  a   b         b   R
    //
    /**
     * Rotate right.  This performs the following operations:
     *  - The left child becomes the parent of this node.
     *  - This node becomes the new parent's right child.
     *  - The old right child of the new parent becomes the left child of this
     *    node.
     */
    Node rotateR()
    {
        // sets _left._parent also
        if (isLeftNode)
            parent.left = _left;
        else
            parent.right = _left;
        Node tmp = _left._right;

        // sets _parent also
        _left.right = &this;

        // sets tmp._parent also
        left = tmp;

        return &this;
    }

    // assumes _right is non null
    //
    // performs rotate-left operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P           P
    //      |    ->     |
    //      T           R
    //     / \         / \
    //    L   R       T   b
    //       / \     / \
    //      a   b   L   a
    //
    /**
     * Rotate left.  This performs the following operations:
     *  - The right child becomes the parent of this node.
     *  - This node becomes the new parent's left child.
     *  - The old left child of the new parent becomes the right child of this
     *    node.
     */
    Node rotateL()
    in
    {
        //assert(_right !is null, "right node must not be null");
    }
    do
    {
        // sets _right._parent also
        if (isLeftNode)
            parent.left = _right;
        else
            parent.right = _right;
        Node tmp = _right._left;

        // sets _parent also
        _right.left = &this;

        // sets tmp._parent also
        right = tmp;
        return &this;
    }


    /**
     * Returns true if this node is a left child.
     *
     * Note that this should always return a value because the root has a
     * parent which is the marker node.
     */
    @property bool isLeftNode() const
    in
    {
        //assert(_parent !is null, "parent must not be null");
    }
    do
    {
        return _parent._left is &this;
    }

    /**
     * Set the color of the node after it is inserted.  This performs an
     * update to the whole tree, possibly rotating nodes to keep the Red-Black
     * properties correct.  This is an O(lg(n)) operation, where n is the
     * number of nodes in the tree.
     *
     * end is the marker node, which is the parent of the topmost valid node.
     */
    void setColor(Node end)
    {
        // test against the marker node
        if (_parent !is end)
        {
            if (_parent.color == Color.Red)
            {
                Node cur = &this;
                while (true)
                {
                    // because root is always black, _parent._parent always exists
                    if (cur._parent.isLeftNode)
                    {
                        // parent is left node, y is 'uncle', could be null
                        Node y = cur._parent._parent._right;
                        if (y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if (cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if (cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if (!cur.isLeftNode)
                                cur = cur._parent.rotateL();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateR();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                    else
                    {
                        // parent is right node, y is 'uncle'
                        Node y = cur._parent._parent._left;
                        if (y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if (cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if (cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if (cur.isLeftNode)
                                cur = cur._parent.rotateR();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateL();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                }

            }
        }
        else
        {
            //
            // this is the root node, color it black
            //
            color = Color.Black;
        }
    }

    /**
     * Remove this node from the tree.  The 'end' node is used as the marker
     * which is root's parent.  Note that this cannot be null!
     *
     * Returns the next highest valued node in the tree after this one, or end
     * if this was the highest-valued node.
     */
    Node remove(Node end)
    {
        //
        // remove this node from the tree, fixing the color if necessary.
        //
        Node x;
        Node ret = next;

        // if this node has 2 children
        if (_left !is null && _right !is null)
        {
            //
            // normally, we can just swap this node's and y's value, but
            // because an iterator could be pointing to y and we don't want to
            // disturb it, we swap this node and y's structure instead.  This
            // can also be a benefit if the value of the tree is a large
            // struct, which takes a long time to copy.
            //
            Node yp, yl, yr;
            Node y = ret; // y = next
            yp = y._parent;
            yl = y._left;
            yr = y._right;
            auto yc = y.color;
            auto isyleft = y.isLeftNode;

            //
            // replace y's structure with structure of this node.
            //
            if (isLeftNode)
                _parent.left = y;
            else
                _parent.right = y;
            //
            // need special case so y doesn't point back to itself
            //
            y.left = _left;
            if (_right is y)
                y.right = &this;
            else
                y.right = _right;
            y.color = color;

            //
            // replace this node's structure with structure of y.
            //
            left = yl;
            right = yr;
            if (_parent !is y)
            {
                if (isyleft)
                    yp.left = &this;
                else
                    yp.right = &this;
            }
            color = yc;
        }

        // if this has less than 2 children, remove it
        if (_left !is null)
            x = _left;
        else
            x = _right;

        bool deferedUnlink = false;
        if (x is null)
        {
            // pretend this is a null node, defer unlinking the node
            x = &this;
            deferedUnlink = true;
        }
        else if (isLeftNode)
            _parent.left = x;
        else
            _parent.right = x;

        // if the color of this is black, then it needs to be fixed
        if (color == color.Black)
        {
            // need to recolor the tree.
            while (x._parent !is end && x.color == Node.Color.Black)
            {
                if (x.isLeftNode)
                {
                    // left node
                    Node w = x._parent._right;
                    if (w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateL();
                        w = x._parent._right;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if ((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if (wr is null || wr.color == Node.Color.Black)
                        {
                            // wl cannot be null here
                            wl.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateR();
                            w = x._parent._right;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._right.color = Node.Color.Black;
                        x._parent.rotateL();
                        x = end.left; // x = root
                    }
                }
                else
                {
                    // right node
                    Node w = x._parent._left;
                    if (w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateR();
                        w = x._parent._left;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if ((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if (wl is null || wl.color == Node.Color.Black)
                        {
                            // wr cannot be null here
                            wr.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateL();
                            w = x._parent._left;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._left.color = Node.Color.Black;
                        x._parent.rotateR();
                        x = end.left; // x = root
                    }
                }
            }
            x.color = Node.Color.Black;
        }

        if (deferedUnlink)
        {
            //
            // unlink this node from the tree
            //
            if (isLeftNode)
                _parent.left = null;
            else
                _parent.right = null;
        }

        // clean references to help GC
        // https://issues.dlang.org/show_bug.cgi?id=12915
        _left = _right = _parent = null;

        return ret;
    }

    /**
     * Return the leftmost descendant of this node.
     */
    @property inout(RBNode)* leftmost() inout
    {
        inout(RBNode)* result = &this;
        while (result._left !is null)
            result = result._left;
        return result;
    }

    /**
     * Return the rightmost descendant of this node
     */
    @property inout(RBNode)* rightmost() inout
    {
        inout(RBNode)* result = &this;
        while (result._right !is null)
            result = result._right;
        return result;
    }

    /**
     * Returns the next valued node in the tree.
     *
     * You should never call this on the marker node, as it is assumed that
     * there is a valid next node.
     */
    @property inout(RBNode)* next() inout
    {
        inout(RBNode)* n = &this;
        if (n.right is null)
        {
            while (!n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.right.leftmost;
    }

    /**
     * Returns the previous valued node in the tree.
     *
     * You should never call this on the leftmost node of the tree as it is
     * assumed that there is a valid previous node.
     */
    @property inout(RBNode)* prev() inout
    {
        inout(RBNode)* n = &this;
        if (n.left is null)
        {
            while (n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.left.rightmost;
    }

    Node dup(scope Node delegate(V v) alloc)
    {
        //
        // duplicate this and all child nodes
        //
        // The recursion should be lg(n), so we shouldn't have to worry about
        // stack size.
        //
        Node copy = alloc(value);
        copy.color = color;
        if (_left !is null)
            copy.left = _left.dup(alloc);
        if (_right !is null)
            copy.right = _right.dup(alloc);
        return copy;
    }

    Node dup()
    {
        Node copy = mallocNew!(RBNode!V)(null, null, null, value); // new RBNode!V(null, null, null, value);
        copy.color = color;
        if (_left !is null)
            copy.left = _left.dup();
        if (_right !is null)
            copy.right = _right.dup();
        return copy;
    }
}

package struct RBRange(N)
{
    alias Node = N;
    alias Elem = typeof(Node.value);

    private Node _begin;
    private Node _end;

    private this(Node b, Node e)
    {
        _begin = b;
        _end = e;
    }

    /**
     * Returns `true` if the range is _empty
     */
    @property bool empty() const
    {
        return _begin is _end;
    }

    /**
     * Returns the first element in the range
     */
    @property Elem front()
    {
        return _begin.value;
    }

    /**
     * Returns the last element in the range
     */
    @property Elem back()
    {
        return _end.prev.value;
    }

    /**
     * pop the front element from the range
     *
     * Complexity: amortized $(BIGOH 1)
     */
    void popFront()
    {
        _begin = _begin.next;
    }

    /**
     * pop the back element from the range
     *
     * Complexity: amortized $(BIGOH 1)
     */
    void popBack()
    {
        _end = _end.prev;
    }

    /**
     * Trivial _save implementation, needed for `isForwardRange`.
     */
    @property RBRange save()
    {
        return this;
    }
}

/**
 * Implementation of a $(LINK2 https://en.wikipedia.org/wiki/Red%E2%80%93black_tree,
 * red-black tree) container.
 *
 * All inserts, removes, searches, and any function in general has complexity
 * of $(BIGOH lg(n)).
 *
 * To use a different comparison than $(D "a < b"), pass a different operator string
 * that can be used by $(REF binaryFun, std,functional), or pass in a
 * function, delegate, functor, or any type where $(D less(a, b)) results in a `bool`
 * value.
 *
 * Note that less should produce a strict ordering.  That is, for two unequal
 * elements `a` and `b`, $(D less(a, b) == !less(b, a)). $(D less(a, a)) should
 * always equal `false`.
 *
 * If `allowDuplicates` is set to `true`, then inserting the same element more than
 * once continues to add more elements.  If it is `false`, duplicate elements are
 * ignored on insertion.  If duplicates are allowed, then new elements are
 * inserted after all existing duplicate elements.
 */
struct RedBlackTree(T, alias less = "a < b", bool allowDuplicates = false)
{
    import std.meta : allSatisfy;
    import std.range : Take;
    import std.range.primitives : isInputRange, walkLength;
    import std.traits : isIntegral, isDynamicArray, isImplicitlyConvertible;

    alias _less = binaryFun!less;

    /**
      * Element type for the tree
      */
    alias Elem = T;

    // used for convenience
    private alias RBNode = .RBNode!Elem;
    private alias Node = RBNode.Node;

    private Node   _end;
    private Node   _begin;
    private size_t _length;

    package void _setup()
    {
        //Make sure that _setup isn't run more than once.
        //assert(!_end, "Setup must only be run once");
        if(!_end)
            _begin = _end = allocate();
    }

    static private Node allocate()
    {
        return mallocNew!(RBNode)();//new RBNode;
    }

    static private Node allocate(Elem v)
    {
        return mallocNew!RBNode(null, null, null, v);//new RBNode(null, null, null, v);
    }

    void rbtfree()
    {
        while(length > 0)
            removeBack();
    }

    /**
     * Creates a shallow copy
     */
    typeof(this) dup(){
        return this;
    }

    /**
     * The range types for `RedBlackTree`
     */
    alias Range = RBRange!(RBNode*);
    alias ConstRange = RBRange!(const(RBNode)*); /// Ditto
    alias ImmutableRange = RBRange!(immutable(RBNode)*); /// Ditto

    // find a node based on an element value
    package inout(RBNode)* _find(Elem e) inout
    {
        static if (allowDuplicates)
        {
            inout(RBNode)* cur = _end.left;
            inout(RBNode)* result = null;
            while (cur)
            {
                if (_less(cur.value, e))
                    cur = cur.right;
                else if (_less(e, cur.value))
                    cur = cur.left;
                else
                {
                    // want to find the left-most element
                    result = cur;
                    cur = cur.left;
                }
            }
            return result;
        }
        else
        {
            inout(RBNode)* cur = _end.left;
            while (cur)
            {
                if (_less(cur.value, e))
                    cur = cur.right;
                else if (_less(e, cur.value))
                    cur = cur.left;
                else
                    return cur;
            }
            return null;
        }
    }

    /* add an element to the tree, returns the node added, or the existing node
     * if it has already been added and allowDuplicates is false
     * Returns:
     *   true if node was added
     */
    private bool _add(return Elem n)
    {
        Node result;
        static if (!allowDuplicates)
            bool added = true;

        if (!_end.left)
        {
            result = allocate(n);
            (() @trusted { _end.left = _begin = result; }) ();
        }
        else
        {
            Node newParent = _end.left;
            Node nxt;
            while (true)
            {
                if (_less(n, newParent.value))
                {
                    nxt = newParent.left;
                    if (nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        result = allocate(n);
                        (() @trusted { newParent.left = result; }) ();
                        break;
                    }
                }
                else
                {
                    static if (!allowDuplicates)
                    {
                        if (!_less(newParent.value, n))
                        {
                            result = newParent;
                            added = false;
                            break;
                        }
                    }
                    nxt = newParent.right;
                    if (nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        result = allocate(n);
                        (() @trusted { newParent.right = result; }) ();
                        break;
                    }
                }
                newParent = nxt;
            }
            if (_begin.left)
                _begin = _begin.left;
        }
        static if (allowDuplicates)
        {
            result.setColor(_end);
            ++_length;
            return true;
        }
        else
        {
            if (added)
            {
                ++_length;
                result.setColor(_end);
            }
            return added;
        }
    }


    /**
     * Check if any elements exist in the container.  Returns `false` if at least
     * one element exists.
     */
    @property bool empty() const // pure, nothrow, @safe, @nogc: are inferred
    {
        return _end.left is null;
    }

    /++
        Returns the number of elements in the container.
        Complexity: $(BIGOH 1).
    +/
    @property size_t length() const
    {
        return _length;
    }

    /**
     * Duplicate this container.  The resulting container contains a shallow
     * copy of the elements.
     *
     * Complexity: $(BIGOH n)
     */
    /* 
    @property RedBlackTree dup()
    {
        return new RedBlackTree(_end.dup(), _length);
    }
    */
    /**
     * Fetch a range that spans all the elements in the container.
     *
     * Complexity: $(BIGOH 1)
     */
    Range opSlice()
    {
        return Range(_begin, _end);
    }

    /// Ditto
    ConstRange opSlice() const
    {
        return ConstRange(_begin, _end);
    }

    /// Ditto
    ImmutableRange opSlice() immutable
    {
        return ImmutableRange(_begin, _end);
    }

    // Find the range for which every element is equal.
    private void findEnclosingRange(Elem e, inout(RBNode)** begin, inout(RBNode)** end) inout
    {
        *begin = _firstGreaterEqual(e);
        *end = _firstGreater(e);
    }
    
    Range range(Elem e)
    {
        RBNode* begin, end;
        findEnclosingRange(e, &begin, &end);
        return Range(begin, end);
    }

    /// Ditto
    ConstRange range(Elem e) const
    {
        const(RBNode)* begin, end;
        findEnclosingRange(e, &begin, &end);
        return ConstRange(begin, end);
    }

    /// Ditto
    ImmutableRange range(Elem e) immutable
    {
        immutable(RBNode)* begin, end;
        findEnclosingRange(e, &begin, &end);
        return ImmutableRange(begin, end);
    }

    /**
     * The front element in the container
     *
     * Complexity: $(BIGOH 1)
     */
    inout(Elem) front() inout
    {
        return _begin.value;
    }

    /**
     * The last element in the container
     *
     * Complexity: $(BIGOH log(n))
     */
    inout(Elem) back() inout
    {
        return _end.prev.value;
    }

    /++
        `in` operator. Check to see if the given element exists in the
        container.
       Complexity: $(BIGOH log(n))
     +/
    bool opBinaryRight(string op)(Elem e) const if (op == "in")
    {
        return _find(e) !is null;
    }

    /**
     * Compares two trees for equality.
     *
     * Complexity: $(BIGOH n)
     */
    bool opEquals(typeof(this) rhs)
    {
        import std.algorithm.comparison : equal;

        RedBlackTree that = cast(RedBlackTree) rhs;
        // if (that is null) return false;

        // If there aren't the same number of nodes, we can't be equal.
        if (this._length != that._length) return false;

        auto thisRange = this[];
        auto thatRange = that[];
        return equal!((Elem a, Elem b) => !_less(a,b) && !_less(b,a))
                     (thisRange, thatRange);
    }

    /**
     * Generates a hash for the tree. Note that with a custom comparison function
     * it may not hold that if two rbtrees are equal, the hashes of the trees
     * will be equal.
     */
    size_t toHash() nothrow @safe
    {
        size_t hash = cast(size_t) 0x6b63_616c_4264_6552UL;
        foreach (ref e; this[])
            // As in boost::hash_combine
            // https://www.boost.org/doc/libs/1_55_0/doc/html/hash/reference.html#boost.hash_combine
            hash += .hashOf(e) + 0x9e3779b9 + (hash << 6) + (hash >>> 2);
        return hash;
    }

    /**
     * Removes all elements from the container.
     *
     * Complexity: $(BIGOH 1)
     */
    void clear()
    {
        _end.left = null;
        _begin = _end;
        _length = 0;
    }

    /**
     * Insert a single element in the container.  Note that this does not
     * invalidate any ranges currently iterating the container.
     *
     * Returns: The number of elements inserted.
     *
     * Complexity: $(BIGOH log(n))
     */
    size_t stableInsert(Stuff)(Stuff stuff) if (isImplicitlyConvertible!(Stuff, Elem))
    {
        lazyInit();
        static if (allowDuplicates)
        {
            _add(stuff);
            return 1;
        }
        else
        {
            return _add(stuff);
        }
    }

    /**
     * Insert a range of elements in the container.  Note that this does not
     * invalidate any ranges currently iterating the container.
     *
     * Returns: The number of elements inserted.
     *
     * Complexity: $(BIGOH m * log(n))
     */
    size_t stableInsert(Stuff)(scope Stuff stuff)
        if (isInputRange!Stuff &&
            isImplicitlyConvertible!(ElementType!Stuff, Elem))
    {
        size_t result = 0;
        static if (allowDuplicates)
        {
            foreach (e; stuff)
            {
                ++result;
                _add(e);
            }
        }
        else
        {
            foreach (e; stuff)
            {
                result += _add(e);
            }
        }
        return result;
    }

    /// ditto
    alias insert = stableInsert;

    /**
     * Remove an element from the container and return its value.
     *
     * Complexity: $(BIGOH log(n))
     */
    Elem removeAny()
    {
        scope(exit)
            --_length;
        auto n = _begin;
        auto result = n.value;
        _begin = n.remove(_end);
        n.deallocate();
        return result;
    }

    /**
     * Remove the front element from the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    void removeFront()
    {
        scope(exit)
            --_length;
        auto oldBegin = _begin;
        _begin = _begin.remove(_end);
        oldBegin.deallocate();
    }

    /**
     * Remove the back element from the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    void removeBack()
    {
        scope(exit)
            --_length;
        auto lastnode = _end.prev;
        if (lastnode is _begin){
            auto oldBegin = _begin;
            _begin = _begin.remove(_end);
            oldBegin.deallocate();
        }else{
            lastnode.remove(_end);
            lastnode.deallocate();
        }
    }

    /++
        Removes the given range from the container.
        Returns: A range containing all of the elements that were after the
                 given range.
        Complexity: $(BIGOH m * log(n)) (where m is the number of elements in
                    the range)
     +/
    Range remove(Range r)
    {
        auto b = r._begin;
        auto e = r._end;
        if (_begin is b)
            _begin = e;
        while (b !is e)
        {
            auto oldb = b;
            b = b.remove(_end);
            --_length;
            oldb.deallocate();
        }
        
        return Range(e, _end);
    }

    /++
        Removes the given `Take!Range` from the container
        Returns: A range containing all of the elements that were after the
                 given range.
        Complexity: $(BIGOH m * log(n)) (where m is the number of elements in
                    the range)
     +/
    
    Range remove(Take!Range r)
    {
        immutable isBegin = (r.source._begin is _begin);
        auto b = r.source._begin;

        while (!r.empty)
        {
            r.popFront();
            auto oldb = b;
            b = b.remove(_end);
            --_length;
            oldb.deallocate();
        }

        if (isBegin)
            _begin = b;

        return Range(b, _end);
    }
    
    /++
       Removes elements from the container that are equal to the given values
       according to the less comparator. One element is removed for each value
       given which is in the container. If `allowDuplicates` is true,
       duplicates are removed only if duplicate values are given.
       Returns: The number of elements removed.
       Complexity: $(BIGOH m log(n)) (where m is the number of elements to remove)
       Example:
--------------------
auto rbt = redBlackTree!true(0, 1, 1, 1, 4, 5, 7);
rbt.removeKey(1, 4, 7);
assert(equal(rbt[], [0, 1, 1, 5]));
rbt.removeKey(1, 1, 0);
assert(equal(rbt[], [5]));
--------------------
      +/
    size_t removeKey(U...)(U elems)
        if (allSatisfy!(isImplicitlyConvertibleToElem, U))
    {
        Elem[U.length] toRemove = [elems];
        return removeKey(toRemove[]);
    }

    /++ Ditto +/
    size_t removeKey(U)(scope U[] elems)
        if (isImplicitlyConvertible!(U, Elem))
    {
        immutable lenBefore = length;

        foreach (e; elems)
        {
            auto beg = _firstGreaterEqual(e);
            if (beg is _end || _less(e, beg.value))
                // no values are equal
                continue;
            auto oldBeg = beg;
            immutable isBegin = (beg is _begin);
            beg = beg.remove(_end);
            if (isBegin)
                _begin = beg;
            --_length;
            oldBeg.deallocate();
        }

        return lenBefore - length;
    }

    /++ Ditto +/
    size_t removeKey(Stuff)(Stuff stuff)
        if (isInputRange!Stuff &&
           isImplicitlyConvertible!(ElementType!Stuff, Elem) &&
           !isDynamicArray!Stuff)
    {
        import std.array : array;
        //We use array in case stuff is a Range from this RedBlackTree - either
        //directly or indirectly.
        return removeKey(array(stuff));
    }

    //Helper for removeKey.
    private template isImplicitlyConvertibleToElem(U)
    {
        enum isImplicitlyConvertibleToElem = isImplicitlyConvertible!(U, Elem);
    }

    // find the first node where the value is > e
    private inout(RBNode)* _firstGreater(Elem e) inout
    {
        // can't use _find, because we cannot return null
        auto cur = _end.left;
        inout(RBNode)* result = _end;
        while (cur)
        {
            if (_less(e, cur.value))
            {
                result = cur;
                cur = cur.left;
            }
            else
                cur = cur.right;
        }
        return result;
    }

    // find the first node where the value is >= e
    private inout(RBNode)* _firstGreaterEqual(Elem e) inout
    {
        // can't use _find, because we cannot return null.
        auto cur = _end.left;
        inout(RBNode)* result = _end;
        while (cur)
        {
            if (_less(cur.value, e))
                cur = cur.right;
            else
            {
                result = cur;
                cur = cur.left;
            }

        }
        return result;
    }

    /**
     * Get a range from the container with all elements that are > e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    Range upperBound(Elem e)
    {
        return Range(_firstGreater(e), _end);
    }

    /// Ditto
    ConstRange upperBound(Elem e) const
    {
        return ConstRange(_firstGreater(e), _end);
    }

    /// Ditto
    ImmutableRange upperBound(Elem e) immutable
    {
        return ImmutableRange(_firstGreater(e), _end);
    }

    /**
     * Get a range from the container with all elements that are < e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    Range lowerBound(Elem e)
    {
        return Range(_begin, _firstGreaterEqual(e));
    }

    /// Ditto
    ConstRange lowerBound(Elem e) const
    {
        return ConstRange(_begin, _firstGreaterEqual(e));
    }

    /// Ditto
    ImmutableRange lowerBound(Elem e) immutable
    {
        return ImmutableRange(_begin, _firstGreaterEqual(e));
    }

    /**
     * Get a range from the container with all elements that are == e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    auto equalRange(this This)(Elem e)
    {
        auto beg = _firstGreaterEqual(e);
        alias RangeType = RBRange!(typeof(beg));
        if (beg is _end || _less(e, beg.value))
            // no values are equal
            return RangeType(beg, beg);
        static if (allowDuplicates)
        {
            return RangeType(beg, _firstGreater(e));
        }
        else
        {
            // no sense in doing a full search, no duplicates are allowed,
            // so we just get the next node.
            return RangeType(beg, beg.next);
        }
    }

    /**
     * Constructor. Pass in an array of elements, or individual elements to
     * initialize the tree with.
     */
    this(Elem[] elems...)
    {
        _setup();
        stableInsert(elems);
    }

    /**
     * Constructor. Pass in a range of elements to initialize the tree with.
     */
    this(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Elem))
    {
        _setup();
        stableInsert(stuff);
    }

    ///
    
    void lazyInit()
    {
        if(isNull)
            _setup();
    }

    bool isNull() const {
        return _end is null;
    }

    private this(Node end, size_t length)
    {
        _end = end;
        _begin = end.leftmost;
        _length = length;
    }
}

import std.range.primitives : isInputRange, ElementType;
import std.traits : isArray, isSomeString;

/++
    Convenience function for creating a `RedBlackTree!E` from a list of
    values.
    Params:
        allowDuplicates =  Whether duplicates should be allowed (optional, default: false)
        less = predicate to sort by (optional)
        elems = elements to insert into the rbtree (variadic arguments)
        range = range elements to insert into the rbtree (alternative to elems)
  +/
auto redBlackTree(E)(E[] elems...)
{
    return RedBlackTree!E(elems);//new RedBlackTree!E(elems);
}

/++ Ditto +/
auto redBlackTree(bool allowDuplicates, E)(E[] elems...)
{
    return RedBlackTree!(E, "a < b", allowDuplicates)(elems);//new RedBlackTree!(E, "a < b", allowDuplicates)(elems);
}

/++ Ditto +/
auto redBlackTree(alias less, E)(E[] elems...)
if (is(typeof(binaryFun!less(E.init, E.init))))
{
    return RedBlackTree!(E, less)(elems);//new RedBlackTree!(E, less)(elems);
}

/++ Ditto +/
auto redBlackTree(alias less, bool allowDuplicates, E)(E[] elems...)
if (is(typeof(binaryFun!less(E.init, E.init))))
{
    //We shouldn't need to instantiate less here, but for some reason,
    //dmd can't handle it if we don't (even though the template which
    //takes less but not allowDuplicates works just fine).
    return RedBlackTree!(E, binaryFun!less, allowDuplicates)(elems);//new RedBlackTree!(E, binaryFun!less, allowDuplicates)(elems);
}

/++ Ditto +/
auto redBlackTree(Stuff)(Stuff range)
if (isInputRange!Stuff && !isArray!(Stuff))
{
    return RedBlackTree!(ElementType!Stuff)(range);//new RedBlackTree!(ElementType!Stuff)(range);
}

/++ Ditto +/
auto redBlackTree(bool allowDuplicates, Stuff)(Stuff range)
if (isInputRange!Stuff && !isArray!(Stuff))
{
    return RedBlackTree!(ElementType!Stuff, "a < b", allowDuplicates)(range); //new RedBlackTree!(ElementType!Stuff, "a < b", allowDuplicates)(range);
}

/++ Ditto +/
auto redBlackTree(alias less, Stuff)(Stuff range)
if ( is(typeof(binaryFun!less((ElementType!Stuff).init, (ElementType!Stuff).init)))
    && isInputRange!Stuff && !isArray!(Stuff))
{
    return RedBlackTree!(ElementType!Stuff, less)(range);//new RedBlackTree!(ElementType!Stuff, less)(range);
}

/++ Ditto +/
auto redBlackTree(alias less, bool allowDuplicates, Stuff)(Stuff range)
if ( is(typeof(binaryFun!less((ElementType!Stuff).init, (ElementType!Stuff).init)))
    && isInputRange!Stuff && !isArray!(Stuff))
{
    //We shouldn't need to instantiate less here, but for some reason,
    //dmd can't handle it if we don't (even though the template which
    //takes less but not allowDuplicates works just fine).
    return RedBlackTree!(ElementType!Stuff, binaryFun!less, allowDuplicates)(range);//new RedBlackTree!(ElementType!Stuff, binaryFun!less, allowDuplicates)(range);
}

// TODO: some unittest
/*
extern(C) int main() @nogc nothrow
{
    import core.stdc.stdio;
    
    auto rbt = redBlackTree(3, 1, 4, 2, 5);
    scope(exit) rbt.rbtfree;

    rbt.removeKey(1,2);

    auto rbt2 = rbt.dup; // shallow copy, no extra heap

    printf("%d\n", rbt2.front);

    RedBlackTree!int rbt3;
    scope(exit) rbt3.rbtfree;

    rbt3.insert(3);

    printf("%d\n", rbt3.front);

    return 0;
}
*/
import core.stdc.stdlib: malloc, realloc, free;

auto mallocNew(T, Args...)(Args args)
{
    immutable size_t allocSize = T.sizeof;

    T* obj = cast(T*)malloc(allocSize);
    *obj = T(args);
    return obj;
}

void destroyFree(T)(T* p)
{
    if (p !is null)
    {
        free(cast(void*)p);
        p = null;
    }
}