/**
This module implements an associative array.
@nogc associative array, replacement for std::map and std::set.
Implementation of Red Black Tree from Phobos.
Copyright: Guillaume Piolat 2015-2016.
Copyright: Copyright (C) 2008- by Steven Schveighoffer. Other code
Copyright: 2010- Andrei Alexandrescu. All rights reserved by the respective holders.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Authors: Steven Schveighoffer, $(HTTP erdani.com, Andrei Alexandrescu), Guillaume Piolat
*/
module bcrbtree.bcmap;

import std.functional : binaryFun;

import bcrbtree.bcrbtree;

struct Map(K, V, alias less = "a < b", bool allowDuplicates = false)
{
public:
nothrow:
@nogc:

    this(int dummy)
    {
        lazyInitialize();
    }

    @disable this(this);

    ~this()
    {
        if (!_rbt.isNull)
        {
            _rbt.rbtfree();
            
        }
    }

    /// Insert an element in the container, if the container doesn't already contain 
    /// an element with equivalent key. 
    /// Returns: `true` if the insertion took place.
    bool insert(K key, V value)
    {
        lazyInitialize();

        auto kv = KeyValue(key, value);
        
        return _rbt.insert(kv) != 0;
    }

    /// Removes an element from the container.
    /// Returns: `true` if the removal took place.
    bool remove(K key)
    {
        if (!isInitialized)
            return false;

        auto kv = KeyValue(key, V.init);
        return _rbt.removeKey(kv) != 0;
    }

    /// Removes all elements from the map.
    void clearContents()
    {
        if (!isInitialized)
            return;

        while(_rbt.length > 0)
            _rbt.removeBack();
    }

    /// Returns: A pointer to the value corresponding to this key, or null if not available.
    ///          Live builtin associative arrays.
    inout(V)* opBinaryRight(string op)(K key) inout if (op == "in")
    {
        if (!isInitialized)
            return null;

        auto kv = KeyValue(key, V.init);
        auto node = _rbt._find(kv);
        if (node is null)
            return null;
        else
            return &node.value.value;
    }

    /// Returns: A reference to the value corresponding to this key.
    ref inout(V) opIndex(K key) inout
    {
        inout(V)* p = key in this;
        return *p;
    }

    /// Updates a value associated with a key, creates it if necessary.
    void opIndexAssign(V value, K key)
    {
        // PERF: this could be faster
        V* p = key in this;
        if (p is null)
            insert(key, value);
        else
            *p = value;
    }

    static if(is(immutable K == immutable C[], C) &&
        (is(C == char) || is(C == wchar) || is(C == dchar))) {
        @property auto opDispatch(K key)() {
            return opIndex(key);
        }

        @property auto opDispatch(K key)(scope const V value) {
            return opIndexAssign(value, key);
        }
    }

    /// Returns: `true` if this key is contained.
    bool contains(K key) const
    {
         if (!isInitialized)
            return false;
        auto kv = KeyValue(key, V.init);
        return (kv in _rbt);
    }

    /// Returns: Number of elements in the map.
    size_t length() const
    {
        if (!isInitialized)
            return 0;

        return _rbt.length();
    }

    /// Returns: `ttue` is the map has no element.
    bool empty() const
    {
        if (!isInitialized)
            return true;
        return _rbt.length() == 0;
    }

    // Iterate by value only

    /// Fetch a forward range on all values.
    Range!(MapRangeType.value) byValue()
    {
        if (!isInitialized)
            return Range!(MapRangeType.value).init;

        return Range!(MapRangeType.value)(_rbt[]);
    }

    /// ditto
    ConstRange!(MapRangeType.value) byValue() const
    {
        if (!isInitialized)
            return ConstRange!(MapRangeType.value).init;

        return ConstRange!(MapRangeType.value)(_rbt[]);
    }

    /// ditto
    ImmutableRange!(MapRangeType.value) byValue() immutable
    {
        if (!isInitialized)
            return ImmutableRange!(MapRangeType.value).init;
        
        return ImmutableRange!(MapRangeType.value)(_rbt[]);
    }

    // default opSlice is like byValue for builtin associative arrays
    alias opSlice = byValue;

    // Iterate by key only

    /// Fetch a forward range on all keys.
    Range!(MapRangeType.key) byKey()
    {
        if (!isInitialized)
            return Range!(MapRangeType.key).init;

        return Range!(MapRangeType.key)(_rbt[]);
    }

    /// ditto
    ConstRange!(MapRangeType.key) byKey() const
    {
        if (!isInitialized)
            return ConstRange!(MapRangeType.key).init;

        return ConstRange!(MapRangeType.key)(_rbt[]);
    }

    /// ditto
    ImmutableRange!(MapRangeType.key) byKey() immutable
    {
        if (!isInitialized)
            return ImmutableRange!(MapRangeType.key).init;

        return ImmutableRange!(MapRangeType.key)(_rbt[]);
    }

    // Iterate by key-value

    /// Fetch a forward range on all keys.
    Range!(MapRangeType.keyValue) byKeyValue()
    {
        if (!isInitialized)
            return Range!(MapRangeType.keyValue).init;

        return Range!(MapRangeType.keyValue)(_rbt[]);
    }

    /// ditto
    ConstRange!(MapRangeType.keyValue) byKeyValue() const
    {
        if (!isInitialized)
            return ConstRange!(MapRangeType.keyValue).init;

        return ConstRange!(MapRangeType.keyValue)(_rbt[]);
    }

    /// ditto
    ImmutableRange!(MapRangeType.keyValue) byKeyValue() immutable
    {
        if (!isInitialized)
            return ImmutableRange!(MapRangeType.keyValue).init;

        return ImmutableRange!(MapRangeType.keyValue)(_rbt[]);
    }

    // Iterate by single value (return a range where all elements have equal key)

    /// Fetch a forward range on all elements with given key.
    Range!(MapRangeType.value) byGivenKey(K key)
    {
       if (!isInitialized)
            return Range!(MapRangeType.value).init;

        auto kv = KeyValue(key, V.init);
        return Range!(MapRangeType.value)(_rbt.range(kv));
    }

    /// ditto
    ConstRange!(MapRangeType.value) byGivenKey(K key) const
    {
        if (!isInitialized)
            return ConstRange!(MapRangeType.value).init;

        auto kv = KeyValue(key, V.init);
        return ConstRange!(MapRangeType.value)(_rbt.range(kv));
    }

    /// ditto
    ImmutableRange!(MapRangeType.value) byGivenKey(K key) immutable
    {
        if (!isInitialized)
            return ImmutableRange!(MapRangeType.value).init;

        auto kv = KeyValue(key, V.init);
        return ImmutableRange!(MapRangeType.value)(_rbt.range(kv));
    }


private:

    alias Range(MapRangeType type) = MapRange!(RBNode!KeyValue*, type);
    alias ConstRange(MapRangeType type) = MapRange!(const(RBNode!KeyValue)*, type); /// Ditto
    alias ImmutableRange(MapRangeType type) = MapRange!(immutable(RBNode!KeyValue)*, type); /// Ditto

    alias _less = binaryFun!less;
    static bool lessForAggregate(const(KeyValue) a, const(KeyValue) b)
    {
        return _less(a.key, b.key);
    }

    alias InternalTree = RedBlackTree!(KeyValue, lessForAggregate, allowDuplicates);

    // we need a composite value to reuse Phobos RedBlackTree
    static struct KeyValue
    {
    nothrow:
    @nogc:
        K key;
        V value;
    }

    InternalTree _rbt;

    bool isInitialized() const
    {
        return !_rbt.isNull;
    }

    void lazyInitialize()
    {
        if (_rbt.isNull)
        {
            _rbt._setup();
        }
    }
}

private enum MapRangeType
{
    key,
    value,
    keyValue
}

private struct MapRange(N, MapRangeType type)
{
nothrow:
@nogc:

    alias Node = N;
    alias InnerRange = RBRange!N;

    static if (type == MapRangeType.key)
        alias Elem = typeof(Node.value.key);

    else static if (type == MapRangeType.value)
        alias Elem = typeof(Node.value.value);

    else static if (type == MapRangeType.keyValue)
        alias Elem = typeof(Node.value);

    static Elem get(InnerRange.Elem pair)
    {
        static if (type == MapRangeType.key)
            return pair.key;

        else static if (type == MapRangeType.value)
            return pair.value;

        else static if (type == MapRangeType.keyValue)
            return pair;
    }

    // A Map range is just a wrapper around a RBRange
    private InnerRange _inner;

    private this(InnerRange inner)
    {
        _inner = inner;
    }

    /**
    * Returns $(D true) if the range is _empty
    */
    @property bool empty() const
    {
        return _inner.empty;
    }

    /**
    * Returns the first element in the range
    */
    @property Elem front()
    {
        return get(_inner.front);
    }

    /**
    * Returns the last element in the range
    */
    @property Elem back()
    {
        return get(_inner.back());
    }

    /**
    * pop the front element from the range
    *
    * complexity: amortized $(BIGOH 1)
    */
    void popFront()
    {
        _inner.popFront();
    }

    /**
    * pop the back element from the range
    *
    * complexity: amortized $(BIGOH 1)
    */
    void popBack()
    {
        _inner.popBack();
    }

    /**
    * Trivial _save implementation, needed for $(D isForwardRange).
    */
    @property MapRange save()
    {
        return this;
    }
}