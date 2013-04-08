
Rx.pl
=====

Microsoft Reactive Extensions Clone in Perl

Dependencies
------------

Moose, aliased, Coro, EV, AnyEvent, Set::Object, Cairo, Gtk3, EV::Glib, Glib,
JSON, autobox::Core

Examples
--------

### Sketch ###

To create a mouse sketching program, we want to transform low-level mouse
events in to a single application level event called _sketch_. The sketch
handler requires a pair of points. It will draw a line between them. We
need to make sure the handler gets called on the correct events, and with the
correct args:

- when mouse is moved, and button is pressed, we want an event, with
  the pair of points being the start and end positions of the mouse,
  so that we can draw a line between them

- on mouse press followed by release we want an event, with the pair of
  points being equal, so we can draw a point

Here is how we build the $sketch observable stream:

    $button_press   = Observable->from_mouse_press($canvas)
                                ->map(sub{ 1 });
    $button_release = Observable->from_mouse_release($canvas)
                                ->map(sub{ 0 });

    $button_stream = $button_press->merge($button_release)
                                  ->unshift(0);

    $motion_stream = Observable->from_mouse_motion($canvas)
                               ->map(sub{ [$_->x, $_->y] })
                               ->unshift( [$window->get_pointer] );

    $sketch = $button_stream->combine_latest($motion_stream)
                            ->buffer(2, 1)
                            ->grep(sub{ $_->[1]->[0] })
                            ->map(sub{ [map { @{$_->[1]} } @$_]});

When you subscribe, you will get point pairs exactly as per the spec above,
and all you need to do is draw a line (or a point if the positions are 
identical):

    $sketch->subscribe(sub{
        my ($x0, $y0, $x1, $y1) = @{$_[0]};
        draw_line_between_two_points($x0, $y0, $x1, $y1);
    })

Lets go over how the $sketch observable stream is built, going from
low-level to high-level events, and showing the marble diagrams for the
combinators applied:

    $button_press   = Observable->from_mouse_press($canvas)
                                ->map(sub{ 1 });
    $button_release = Observable->from_mouse_release($canvas)
                                ->map(sub{ 0 });

This gives us 2 streams, one per mouse event, which we project to bools.

    $button_stream  = $button_press->merge($button_release)
                                   ->unshift(0);

We merge them, and start the event with 0, assuming the user starts with
button released. No way in Gtk actually to check this, but lets assume.

Here is how a pair of mouse clicks would look like in a marble diagram:

      ---time-->
    $button_press   ----------1--------------------1------------
    $button_release ----------------0----------------------0----
    merge           ----------1-----0--------------1-------0----
    unshift(0)      0---------1-----0--------------1-------0----

Another primitive stream of mouse events:    

    $motion_stream = $Observable->from_mouse_motion($canvas)
                                ->map(sub{ [$_->x, $_->y] })
                                ->unshift( [$window->get_pointer] ));

We project it using _map_ to the mouse coordinates, which is all we need from
the notification, and make sure it starts with the real initial location of the
mouse.

Now the crux of the biscuit, which we will go over line-by-line:

    $sketch = $button_stream->combine_latest($motion_stream)

_combine_latest_ passes every event from both streams. It attaches to each
notification from one of the stream, the last received value from the other
stream. So we now have a tuple of [button\_state, mouse\_position] fired
on each button press/release/mouse move.

Here is the marble diagram for a button press, followed by some mouse motion
and a button release, as we would get it after piping through
_combine_latest_. Pi is i-th position of mouse.

      ---time-->
    $button_stream -0--------1-----------------------------0-----
    $motion_stream ---P1---------------P2--------P3--------------
    combine_latest -[0,P1]-[1,P1]----[1,P2]----[1,P3]----[0,P3]--

However, we are interested in pairs of points:    

                            ->buffer(2, 1)

Buffer(2,1) buffers every pair of events from _combine_latest_, and
shifts the buffer one event to the right. Thus we get a pair of the
latest 2 notifications. Here is the stream above piped though _buffer_:

      ---time-->

    combine_latest -[0,P1]-[1,P1]----[1,P2]----[1,P3]----[0,P3]--
                          [[0,P1],  [[1,P1],  [[1,P2],  [[1,P3], 
    buffer(2,1)    ------- [1,P1],---[1,P2],---[1,P3],---[0,P3],-
                          ]         ]         ]         ]

Turns out the we are only interested in those notifications which end in a
mouse press state. Here is a list of the possible pair types we will
receive:

    [[0,Pi],[0,Pj]] - don't draw, mouse is being moved without button press
    [[1,Pi],[1,Pj]] - draw a line [Pi,Pj] because user is sketching
    [[0,Pi],[1,Pi]] - draw a point, which is just the line [Pi,Pi]
    [[1,Pi],[0,Pi]] - mouse being released, don't draw anything

We can find the notifications we need using grep. We seek only those buffers
where the second event was fired with button pressed:

                            ->grep(sub{ $_->[1]->[0] })

Finally we map the notifications into a pair of x,y coordinates, throwing
away the mouse button state, and flattening them, so that they are ready to
be sent to the sketch subscribers:

                            ->map(sub{ [map { @{$_->[1]} } @$_]});
                            
Leading to the following marble diagram:

                          [[0,P1],  [[1,P1],  [[1,P2],  [[1,P3], 
    buffer(2,1)    ------- [1,P1],---[1,P2],---[1,P3],---[0,P3],-
                          ]         ]         ]         ]
    grep + map     -------[P1,P1]---[P1,P2]---[P2,P3]------------

And here is the entire pipeline in one big image, showing a short
sketch session, from mouse events to the sketch event:

![Sketch Marble Diagram](doc/sketch_marble_diagram.png)


What Works
----------

* once
* range
* empty
* never
* throw
* from\_list
* subject
* publish
* defer
* interval
* timer
* from\_stdin
* let
* map
* expand
* grep
* count
* take
* take\_last
* skip
* distinct\_changes
* buffer
* push
* unshift
* merge 2 observables, N observables, observable of observables
* combine\_latest
* delay
* do
* foreach
* from\_http\_get using AnyEvent::HTTP
* Gtk3 from\_mouse\_press, from\_mouse\_release, from\_mouse\_motion


Differences vs. .NET Rx
-----------------------

* we don't call dispose and use Perl ref counting instead

* more Perlish operator names


TODO
----

* skip/take while/until/last, first/last
  timestamp, max/min/sum/average, fold/scan,
  repeat (resubscribes to self), retry, any, all, group by,
  fork join, blocking to\_list, replay subject,
  ref count connectable, timestamp, time\_interval,
  async subject prune


* timeout - from subscription to 1st on\_next and timeout
  between on\_next

* decide- does this use Coro, EV, Coro::EV, Coro::AnyEvent and/or
  AnyEvent? EV works nicely with EV::Glib and Gtk3 at least on 
  Linux, AnyEvent is more common for Http work, Coro is awesome
  but is it required? Currently uses a mish-mash of string, glue, fog,
  mirrors, and every single one of the above mentioned modules

* "K 1" instead of "sub{ 1 }"

* Void and "KVoid" instead of 1 and "sub { 1 }"

* test from\_stdin with unsubscribe, maybe cleanup should reset handle

* try deep recursion

* too many similar observables inherit from Composite- tease another
  class out of there

* http client needs http\_get\_json

* support take(0)

* distinct\_changes should have a comparator param

* connectable observable connect() should return disposable
  instead of disconnect hack

* use ref count connectable for hot observables with retries

* take\_while/skip/until should take sub or observable, "while"
  does not include edge, "until" does

* observable from SDL mouse/keyboard events, sockets, filesystem events

* demos- autocomplete with some terminal toolkit and menus, drag&drop,
  inactivity timer, perl news feed, perl activity graph, time flies,
  online spellchecker, image download robot, proxy, konami code, sketch 
  with bleeding ink and smoothing, erase, color change, etc. stock
  ticker with running averages, max, stddev and other window funcs,
  promise examples

LINKS
-----

https://github.com/richardszalay/raix/wiki/Reactive-Operators
http://search.cpan.org/~miyagawa/Corona-0.1004/lib/Corona.pm
http://search.cpan.org/~alexmv/Net-Server-Coro-1.3/lib/Net/Server/Coro.pm
http://www.youtube.com/watch?v=ClHpkn\_qxos
https://github.com/Reactive-Extensions/RxJS/wiki/Observable
https://github.com/richardszalay/raix/blob/master/source/raix/src/raix/reactive/Observable.as
http://code.google.com/p/rx-samples/source/browse/trunk/src/RxSamples.ConsoleApp/10\_FlowControlExamples.cs
https://github.com/Reactive-Extensions/RxJS-Examples
https://github.com/mono/rx/tree/master/Rx/NET/Source/System.Reactive.Linq/Reactive/Linq
http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx


