using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Library.UnitTests
{
    [TestFixture]
    public class SampleTest
    {
        [Test]
        public void Should_assert_somthing()
        {
            Assert.IsTrue(true);
        }

        [Test]
        public void Should_assert_somthing_in_library()
        {
            var someLibrary = new SomeLibrary();
            Assert.IsTrue(someLibrary.ReturnTrue());
        }
    }
}
