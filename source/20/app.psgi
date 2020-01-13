use strict;
use warnings;
use utf8;
use DBI;
use Data::Section::Simple qw/get_data_section/;
use File::Basename;
use File::Spec;
use JSON;
use Plack::Builder;
use Plack::Request;
use SQL::Maker;

my $sql_builder = SQL::Maker->new(driver => 'SQLite');
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=q20.db",
    '',
    '',
    +{
        RaiseError     => 1,
        sqlite_unicode => 1,
    }
);

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    if ($req->path_info eq '/') {
        return render_html('index.html');
    } elsif ($req->path_info eq '/search' && $req->method eq 'POST') {
        my $q = $req->param('q') // die 'missing q';
        warn "q: $q\n";

        my $where = eval {
            decode_json($q);
        };
        if ($@) {
            die 'illegal JSON';
        }
        die 'missing name parameter' unless $where->{name};
        die 'invalid name parameter' unless $where->{name} =~ /^[\x20-\x7f]+$/;

        for my $key (keys %$where) {
            $where->{$key} =~ s/[%_]//g;
            $where->{$key} = $where->{$key} eq '' ? '' : "%$where->{$key}%";
            $where->{$key} = {like => $where->{$key}};
        }

        my ($sql, @bind) = $sql_builder->select('user', ['*'], $where, {});
        my $users = $dbh->selectall_arrayref($sql, {Slice => {}}, @bind);
        return render_json($users);
    } elsif ($req->path_info eq '/admin') {
        if ($req->method eq 'POST') {
            my $name = $req->param('name') // die 'missing name';
            my $password = $req->param('password') // die 'missing password';
            warn "password: $password\n";

            my ($sql, @bind) = $sql_builder->select('admin_ahq21', ['*'], {
                name_YDODF     => $name,
                password_U6lts => $password,
            }, {});
            my ($admin) = $dbh->selectrow_array($sql, {Slice => {}}, @bind);
            if ($admin) {
                return render_html('flag.html');
            } else {
                return [403, [], ['login failure']];
            }
        } else {
            return render_html('admin.html');
        }
    } elsif ($req->path_info eq '/source') {
        return render_html('source.html');
    } else {
        return [404, [], ['not found']];
    }
};

builder {
    enable 'Plack::Middleware::ReverseProxy';
    enable 'Plack::Middleware::Static',
        path => qr{^/js/},
        root => File::Spec->catdir(dirname(__FILE__));
    $app;
};

sub render_html {
    [
        200,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [get_data_section($_[0])]
    ]
}

sub render_json {
    [
        200,
        ['Content-Type' => 'application/json; charset=utf-8'],
        [encode_json($_[0])]
    ]
}

__DATA__

@@ index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>searcher</title>
    <script src="/js/jquery-1.9.1.min.js"></script>
    <script>
$(function () {
    $("#search input[name='name']").focus().keyup(function() {
        var submit = $("#search input[type='submit']");
        if ($(this).val() === "") {
            submit.attr("disabled", "disabled");
        } else {
            submit.removeAttr("disabled");
        }
    });

    $("#search").submit(function() {
        var name = $("#search input[name='name']").val();
        if (name === "") return false;

        $.ajax("/search", {
            type: "POST",
            dataType: "json",
            data: {
                q: JSON.stringify({"name": name})
            },
            success: function(data, textStatus, jqXHR) {
                $("#result .row").remove();
                for (var i = 0, length = data.length; i < length; i++) {
                    var tr = $("<tr />").addClass("row");
                    var password = data[i].password.replace(/./g, '*');
                    tr.append($("<td />").text(data[i].name));
                    tr.append($("<td />").text(password));
                    $("#result").append(tr);
                }
            }
        });
        return false;
    });
});
    </script>
</head>
<body>

<p>Q. How do I login admin page?</p>

<form id="search">
    <input type="text" name="name" />
    <input type="submit" value="Search" disabled="disabled" />
</form>

<h2>Search result: user</h2>

<table id="result" border="1">
    <tr>
        <th>name</th>
        <th>password</th>
    </tr>
</table>

<hr />

<p>Go to <a href="/admin">admin page</a><p>

</body>
</html>

@@ admin.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>searcher</title>
</head>
<body>

<form method="POST" action="/admin">
    Password: <input type="password" name="password" />
    <input type="hidden" name="name" value="admin" />
    <input type="submit" value="Login" />
</form>

</body>
</html>

@@ flag.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>searcher</title>
</head>
<body>

<pre> ____   U  ___ u  _   _     ____     ____        _       _____    _   _    _         _       _____             U  ___ u  _   _    ____     _    
U /"___|   \/"_ \/ | \ |"| U /"___|uU |  _"\ u U  /"\  u  |_ " _|U |"|u| |  |"|    U  /"\  u  |_ " _|     ___     \/"_ \/ | \ |"|  / __"| uU|"|u  
\| | u     | | | |<|  \| |>\| |  _ / \| |_) |/  \/ _ \/     | |   \| |\| |U | | u   \/ _ \/     | |      |_"_|    | | | |<|  \| |><\___ \/ \| |/  
 | |/__.-,_| |_| |U| |\  |u | |_| |   |  _ <    / ___ \    /| |\   | |_| | \| |/__  / ___ \    /| |\      | | .-,_| |_| |U| |\  |u u___) |  |_|   
  \____|\_)-\___/  |_| \_|   \____|   |_| \_\  /_/   \_\  u |_|U  <<\___/   |_____|/_/   \_\  u |_|U    U/| |\u\_)-\___/  |_| \_|  |____/>> (_)   
 _// \\      \\    ||   \\,-._)(|_    //   \\_  \\    >>  _// \\_(__) )(    //  \\  \\    >>  _// \\_.-,_|___|_,-.  \\    ||   \\,-.)(  (__)|||_  
(__)(__)    (__)   (_")  (_/(__)__)  (__)  (__)(__)  (__)(__) (__)   (__)  (_")("_)(__)  (__)(__) (__)\_)-' '-(_/  (__)   (_")  (_/(__)    (__)_)</pre>

<p>The flag is <code>admin's password</code>.</p>

</body>
</html>
