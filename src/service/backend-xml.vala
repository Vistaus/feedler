/**
 * backend-xml.vala
 * 
 * @author Daniel Kur <Daniel.M.Kur@gmail.com>
 * @see COPYING
 */

internal class Subscriptions
{
    internal GLib.List<Model.Folder?> folders;
    internal GLib.List<Model.Channel?> channels;

    internal bool parse (Xml.Doc data)
    {
        unowned Xml.Node root = data.get_root_element ();
        if (root.name == "opml")
        {
            this.channels = new GLib.List<Model.Channel?> ();
            this.folders = new GLib.List<Model.Folder?> ();
			unowned Xml.Node head_body = root.children;
			while (head_body != null)
			{
				if (head_body.name == "body")
				{
					opml (head_body);
					break;
				}
				head_body = head_body.next;
			}
            return true;
		}
        return false;
    }

    private void opml (Xml.Node node)
	{
		unowned Xml.Node outline = node.children;
		string type;
		while (outline != null)
		{
			if (outline.name == "outline")
			{
				type = outline.get_prop ("type");
				if (type == "rss" || type == "atom")
					opml_channel (outline);
				else if (type == "folder" || type == null)
				    opml_folder (outline);
				else
				{
					stderr.printf ("Following type is currently not supported: %s.\n", type);
					continue;
				}
			}
			outline = outline.next;
		}		
	}

    private void opml_folder (Xml.Node node)
	{
		Model.Folder f = Model.Folder ();
        f.name = node.get_prop ("text");
        f.parent = 0;
        if (node.parent->name != "body")
            f.parent = get_parent (node.parent->get_prop ("text"));
        this.folders.append (f);
		opml (node);
	}

    private void opml_channel (Xml.Node node)
	{
		Model.Channel c = new Model.Channel ();
		c.title = node.get_prop ("text");
		c.source = node.get_prop ("xmlUrl");
		c.link = node.get_prop ("htmlUrl");
        c.folder = 0;
        if (node.parent->name != "body")
            c.folder = get_parent (node.parent->get_prop ("text"));
        this.channels.append (c);
	}

    private int get_parent (string name)
    {
        foreach (Model.Folder folder in this.folders)
            if (folder.name == name)
                return folder.id;
        return 0;
    }
}

internal class Feeds
{
    internal Model.Channel channel;

    internal bool parse (Xml.Doc data)
    {
        unowned Xml.Node root = data.get_root_element ();
        this.channel = new Model.Channel ();
        this.channel.items = new GLib.List<Model.Item?> ();
        switch (root.name)
		{
            case "rss":
                rss (root);  break;
            case "feed":
                atom (root); break;
            default:
                return false;
		}
        return true;
    }

    private void rss (Xml.Node* channel)
    {
        for (Xml.Node* iter = channel->children; iter != null; iter = iter->next)
		{
            if (iter->type != Xml.ElementType.ELEMENT_NODE)
                continue;
            
            if (iter->name == "item")
				rss_item (iter);
            else if (iter->name == "title")
				this.channel.title = iter->get_content ();
			else if (iter->name == "link")
				this.channel.link = iter->get_content ();
            else
				rss (iter);
        }
    }

    private void rss_item (Xml.Node* iitem)
    {
		Model.Item item = Model.Item ();
		for (Xml.Node* iter = iitem->children; iter != null; iter = iter->next)
		{
            if (iter->type != Xml.ElementType.ELEMENT_NODE)
                continue;
            
            if (iter->name == "title")
				item.title = iter->get_content ();
			else if (iter->name == "link")
				item.source = iter->get_content ();
			else if (iter->name == "author" || iter->name == "creator")
				item.author = iter->get_content ();
			else if (iter->name == "description" || iter->name == "encoded")
				item.description = iter->get_content ();
			else if (iter->name == "pubDate")
				item.time = (int)string_to_time_t (iter->get_content ());
        }
        item.state = Model.State.UNREADED;
        if (item.author == null)
			item.author = "Anonymous"; //TODO gettext
		if (item.time == 0)
			item.time = (int)time_t ();
        this.channel.items.append (item);
	}
    
    private void atom (Xml.Node* channel)
	{
		for (Xml.Node* iter = channel->children; iter != null; iter = iter->next)
		{
            if (iter->type != Xml.ElementType.ELEMENT_NODE)
                continue;
            
            if (iter->name == "entry")
				atom_item (iter);
            else if (iter->name == "title")
				this.channel.title = iter->get_content ();
			else if (iter->name == "link" && iter->get_prop ("rel") == "alternate")
				this.channel.link = iter->get_prop ("href");
            else
				atom (iter);
        }
	}

    private void atom_item (Xml.Node* iitem)
    {
		Model.Item item = Model.Item ();
		for (Xml.Node* iter = iitem->children; iter != null; iter = iter->next)
		{
            if (iter->type != Xml.ElementType.ELEMENT_NODE)
                continue;

            if (iter->name == "title")
				item.title = iter->get_content ();
			else if (iter->name == "link" && iter->get_prop ("rel") == "alternate")
				item.source = iter->get_prop ("href");
			else if (iter->name == "author")
				item.author = atom_author (iter);
			else if (iter->name == "summary")
				item.description = iter->get_content ();
			else if (iter->name == "updated" || iter->name == "published")
				item.time = (int)string_to_time_t (iter->get_content ());
        }
        item.state = Model.State.UNREADED;
		if (item.time == 0)
			item.time = (int)time_t ();
        this.channel.items.append (item);
	}

    private string atom_author (Xml.Node* iitem)
    {
		for (Xml.Node* iter = iitem->children; iter != null; iter = iter->next)
		{
            if (iter->type != Xml.ElementType.ELEMENT_NODE)
                continue;

            if (iter->name == "name")
                return iter->get_content ();
        }
        return "Anonymous";//TODO gettext
	}
    
    private time_t string_to_time_t (string date)
	{
		Soup.Date time = new Soup.Date.from_string (date);
		return (time_t)time.to_time_t ();
	}
}

public class BackendXml : Backend
{
    public override bool subscribe (string data, out Model.Folder[]? folders, out Serializer.Channel[]? channels)
    {
        unowned Xml.Doc doc = Xml.Parser.parse_file (data);
        if (is_valid (doc))
        {
            var subs = new Subscriptions ();
            if (subs.parse (doc))
            {
                folders = Serializer.List.folders_array (subs.folders);
                channels = Serializer.List.channels_array (subs.channels);
                return true;
            }
        }
        folders = null;
        channels = null;
        return false;
    }

    public override bool refresh (string data, out Serializer.Channel? channel)
    {
        unowned Xml.Doc doc = Xml.Parser.parse_memory (data, data.length);
        if (is_valid (doc))
        {
            var feeds = new Feeds ();
            if (feeds.parse (doc))
            {
                channel = Serializer.Channel.from_model (feeds.channel);
                return true;
            }
        }
        channel = null;
        return false;
    }

    public override void import (string uri)
    {
        stderr.printf ("BackendXML.import (%s)\n", uri);
        try
        {
            ThreadFunc<void*> thread_func = () =>
            {
                Model.Folder[]? folders = null;
                Serializer.Channel[]? channels = null;
                if (this.subscribe (uri, out folders, out channels))
                {
                    this.service.imported (folders, channels);
                }
                return null;
            };
            Thread.create<void*> (thread_func, false);
        }
        catch (GLib.ThreadError e)
        {
            stderr.printf ("Cannot run threads.\n");
        }        
    }

    public override void update (string uri)
    {
        stderr.printf ("BackendXML.update (%s)\n", uri);
        Soup.Message msg = new Soup.Message ("GET", uri);
        session.queue_message (msg, this.update_func);
    }

    public override BACKENDS to_type ()
    {
        return BACKENDS.XML;
    }

    public override string to_string ()
    {
        return "Default XML-based backend.";
    }

    private void update_func (Soup.Session session, Soup.Message message)
	{
        stderr.printf ("BackendXML.update_func %s\n", message.uri.to_string (false));
        string xml = (string)message.response_body.flatten ().data;
        Serializer.Channel? channel = null;
        
        if (xml != null && this.refresh (xml, out channel))
        {
            this.service.updated (channel);
            /*--this.service.connection;
            this.service.unreaded++;
            if (this.service.connection == 0)
            {
                this.service.notification (("%i new feeds").printf (this.service.unreaded)); //TODO gettext
                this.service.unreaded = 0;
            }*/
        }
	}

    private bool is_valid (Xml.Doc doc)
    {
        if (doc == null)
        {
            stderr.printf ("Failed to read the source data.\n");
            return false;
        }

        unowned Xml.Node root = doc.get_root_element ();
        if (root == null)
        {
            stderr.printf ("Source data is empty.\n");
            return false;
        }
        if (root.name != "rss" && root.name != "feed" && root.name != "opml")
        {
            stderr.printf ("Undefined type of data.\n");
            return false;
        }
        return true;
    }
}
