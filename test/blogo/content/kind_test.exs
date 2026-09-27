defmodule Blogo.Content.KindTest do
  @moduledoc """
  What a post is called. The kind was `ensaio` and the line above the title said
  so; it says `artigo` now, and the column was renamed with it rather than left
  disagreeing with the screen.
  """
  use Blogo.DataCase

  alias Blogo.Content
  alias Blogo.Content.Markdown
  alias Blogo.Content.Post

  test "the kinds are the ones the screen names" do
    assert "artigo" in Post.kinds()
    refute "ensaio" in Post.kinds()
  end

  test "a new post is an artigo by default" do
    assert %Post{kind: "artigo"} = %Post{}
  end

  test "ensaio is refused, because it is not a kind any more" do
    changeset = Post.changeset(%Post{}, %{title: "T", slug: "s", kind: "ensaio", author_id: 1})

    assert "is invalid" in errors_on(changeset).kind
  end

  # A document exported as markdown before the rename still carries
  # `tipo: ensaio` in its front matter. Reading it has to keep working: the
  # alternative is that a file saved yesterday comes back as a kind the schema
  # rejects, and the writer loses the document to a word we changed.
  test "a document written before the rename still opens" do
    markdown = """
    ---
    titulo: Um título
    endereco: um-titulo
    tipo: ensaio
    ---

    Algum texto.
    """

    assert {:ok, meta} = Markdown.from_markdown(markdown)
    assert meta.kind == "artigo"
  end

  test "writing always uses the current word" do
    post = %Post{title: "Um título", slug: "um-titulo", kind: "artigo", body: %{"blocks" => []}}

    assert Markdown.to_markdown(post) =~ "tipo: artigo"
  end

  test "a draft created from the panel is an artigo" do
    author = Blogo.Fixtures.author()

    {:ok, post} = Content.new_draft(author.id)

    assert Repo.get!(Post, post.id).kind == "artigo"
  end
end
