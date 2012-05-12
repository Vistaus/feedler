/**
 * client.vala
 * 
 * @author Daniel Kur <Daniel.M.Kur@gmail.com>
 * @see COPYING
 */

void main ()
{
    /* Needed only if your client is listening to signals; you can omit it otherwise */
    var loop = new MainLoop();

    /* Important: keep demo variable out of try/catch scope not lose signals! */
    FeedlerClient demo = null;

    try
    {
        demo = Bus.get_proxy_sync (BusType.SESSION, "org.example.Feedler",
                                                    "/org/example/feedler");

        /* Connecting to signal pong! */
        /*demo.pong.connect((c, m) => {
            stdout.printf ("Got pong %d for msg '%s'\n", c, m);
            loop.quit ();
        });*/

        int pong = demo.ping ("Hello from Vala1");
        stdout.printf ("%d\n", pong);
        
        int pong2 = demo.ping ("Hello from Vala2");
        stdout.printf ("%d\n", pong2);
/*
        pong = demo.ping_with_sender ("Hello from Vala with sender");
        stdout.printf ("%d\n", pong);

        pong = demo.ping_with_signal ("Hello from Vala with signal");
        stdout.printf ("%d\n", pong);
*/
        GLib.Timeout.add_seconds (5, () =>
        {
            demo.stop();
            stderr.printf ("Sending stop call.\n");
            loop.quit ();
            return false;
        });
    }
    catch (GLib.IOError e)
    {
        stderr.printf ("%s\n", e.message);
    }
    loop.run ();
}