# bcrbtree and bcmap
A RedBlackTree port of Phobos suitable for betterC and Map (ordered_dict)

* This is WIP and needs tests before it goes to dub registry

```d
import bcrbtree.bcrbtree;
import bcrbtree.bcmap;

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

    // ordered dict or Map

    Map!(string, string) aa1; // Map is scoped, so it is deallocated on the exit of the scope

    aa1["Stevie"] = "Ray Vaughan";
    aa1["Chris"] = "Rea";
    aa1.Dan = "Patlansky";
    aa1["Robben"] = "Ford";
    aa1["Ferhat"] = "Kurtulmuş";

    aa1.remove("Robben");

    foreach(pair; aa1.byKeyValue()){
        printf("%s -> %s\n", pair.key.ptr, pair.value.ptr);
    }
    
    return 0;
}
```