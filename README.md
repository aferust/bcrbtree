# A RedBlackTree port of Phobos suitable for betterC

- WIP

```d
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
```